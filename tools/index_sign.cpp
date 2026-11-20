// index_sign: signs and checks the core indexes the downloader reads.
//
//   index_sign keygen <secret key file> <public key file>
//   index_sign sign   <secret key file> <file>        writes <file>.sig
//   index_sign verify <public key file> <file>        checks <file>.sig
//
// Signatures are Monocypher's EdDSA (crypto_eddsa_*: Ed25519's curve with
// BLAKE2b instead of SHA-512). piccolo verifies with the same Monocypher (core
// only, no optional/), so this is the scheme, not standard Ed25519: minisign
// or signify signatures wouldn't verify there.
//
// Files are text, one key=value per line (like piccolo's .cfg files):
//   public key:  key_id=<16 hex>  public=<64 hex>
//   secret key:  key_id=<16 hex>  secret=<128 hex>
//   signature:   key_id=<16 hex>  signature=<128 hex>
// key_id = the first 8 bytes of BLAKE2b(public key): piccolo carries two public
// keys (current + next) and picks by it, so a leaked key can be retired.
// The message signed is the exact bytes of the file.
//
// Self-contained (only Monocypher) so it builds with one compiler command in
// the publisher's image. Linux only: keygen reads /dev/urandom.

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include <sys/stat.h>

#include "monocypher.h"

constexpr size_t KEY_ID_SIZE    = 8;
constexpr size_t PUBLIC_SIZE    = 32;
constexpr size_t SECRET_SIZE    = 64;
constexpr size_t SIGNATURE_SIZE = 64;
constexpr size_t SEED_SIZE      = 32;
constexpr size_t MAX_FILE_SIZE  = 64u * 1024u * 1024u;   // indexes are a few KB

static bool read_file(const char* path, std::string* out)
{
    FILE* file = std::fopen(path, "rb");
    if (file == nullptr)
    {
        std::fprintf(stderr, "error: can't open %s\n", path);
        return false;
    }
    out->clear();
    char buffer[16384];
    bool ok = true;
    while (true)
    {
        size_t got = std::fread(buffer, 1, sizeof(buffer), file);
        out->append(buffer, got);
        if (out->size() > MAX_FILE_SIZE)
        {
            std::fprintf(stderr, "error: %s is too large\n", path);
            ok = false;
            break;
        }
        if (got < sizeof(buffer))
        {
            if (std::ferror(file) != 0)
            {
                std::fprintf(stderr, "error: can't read %s\n", path);
                ok = false;
            }
            break;
        }
    }
    std::fclose(file);
    return ok;
}

// Writes next to the target and renames, so a reader never sees half a file.
// `mode` is set before anything is written (0600 for the secret key).
static bool write_file(const char* path, const std::string& text, mode_t mode)
{
    std::string temp = std::string(path) + ".tmp";
    FILE* file = std::fopen(temp.c_str(), "wb");
    if (file == nullptr)
    {
        std::fprintf(stderr, "error: can't create %s\n", temp.c_str());
        return false;
    }
    if (chmod(temp.c_str(), mode) != 0)
    {
        std::fprintf(stderr, "error: can't set permissions on %s\n", temp.c_str());
        std::fclose(file);
        std::remove(temp.c_str());
        return false;
    }
    bool ok = std::fwrite(text.data(), 1, text.size(), file) == text.size();
    ok = (std::fclose(file) == 0) && ok;
    if (ok)
    {
        ok = std::rename(temp.c_str(), path) == 0;
    }
    if (!ok)
    {
        std::fprintf(stderr, "error: can't write %s\n", path);
        std::remove(temp.c_str());
    }
    return ok;
}

static void hex_append(std::string* out, const uint8_t* bytes, size_t size)
{
    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < size; i++)
    {
        out->push_back(digits[bytes[i] >> 4]);
        out->push_back(digits[bytes[i] & 0x0f]);
    }
}

static int32_t hex_digit(char c)
{
    if (c >= '0' && c <= '9')
    {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f')
    {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F')
    {
        return c - 'A' + 10;
    }
    return -1;
}

static bool hex_decode(const std::string& text, uint8_t* out, size_t size)
{
    if (text.size() != size * 2)
    {
        return false;
    }
    for (size_t i = 0; i < size; i++)
    {
        int32_t high = hex_digit(text[i * 2]);
        int32_t low  = hex_digit(text[i * 2 + 1]);
        if (high < 0 || low < 0)
        {
            return false;
        }
        out[i] = static_cast<uint8_t>(high * 16 + low);
    }
    return true;
}

// The value of "key=value" in a key or signature file ("" if absent).
// Lines starting with '#' are comments.
static std::string field_get(const std::string& text, const char* key)
{
    std::string prefix = std::string(key) + "=";
    size_t start = 0;
    while (start < text.size())
    {
        size_t end = text.find('\n', start);
        if (end == std::string::npos)
        {
            end = text.size();
        }
        std::string line = text.substr(start, end - start);
        if (!line.empty() && line.back() == '\r')
        {
            line.pop_back();
        }
        if (line.compare(0, prefix.size(), prefix) == 0)
        {
            return line.substr(prefix.size());
        }
        start = end + 1;
    }
    return std::string();
}

static void key_id_compute(const uint8_t public_key[PUBLIC_SIZE], uint8_t key_id[KEY_ID_SIZE])
{
    crypto_blake2b(key_id, KEY_ID_SIZE, public_key, PUBLIC_SIZE);
}

static bool random_bytes(uint8_t* out, size_t size)
{
    FILE* file = std::fopen("/dev/urandom", "rb");
    if (file == nullptr)
    {
        std::fprintf(stderr, "error: can't open /dev/urandom\n");
        return false;
    }
    bool ok = std::fread(out, 1, size, file) == size;
    std::fclose(file);
    if (!ok)
    {
        std::fprintf(stderr, "error: can't read /dev/urandom\n");
    }
    return ok;
}

static bool command_keygen(const char* secret_path, const char* public_path)
{
    // Never replace a key: indexes signed with it would stop verifying.
    struct stat existing;
    if (stat(secret_path, &existing) == 0 || stat(public_path, &existing) == 0)
    {
        std::fprintf(stderr, "error: %s or %s already exists\n", secret_path, public_path);
        return false;
    }
    uint8_t seed[SEED_SIZE];
    uint8_t secret_key[SECRET_SIZE];
    uint8_t public_key[PUBLIC_SIZE];
    uint8_t key_id[KEY_ID_SIZE];
    if (!random_bytes(seed, sizeof(seed)))
    {
        return false;
    }
    crypto_eddsa_key_pair(secret_key, public_key, seed);   // wipes the seed
    key_id_compute(public_key, key_id);

    std::string id_hex;
    hex_append(&id_hex, key_id, sizeof(key_id));

    std::string public_text = "# multitap core index signing key (public)\nkey_id=" + id_hex + "\npublic=";
    hex_append(&public_text, public_key, sizeof(public_key));
    public_text += "\n";

    std::string secret_text = "# multitap core index signing key (SECRET: never share or commit)\nkey_id=" + id_hex + "\nsecret=";
    hex_append(&secret_text, secret_key, sizeof(secret_key));
    secret_text += "\n";
    crypto_wipe(secret_key, sizeof(secret_key));

    bool ok = write_file(secret_path, secret_text, 0600) && write_file(public_path, public_text, 0644);
    crypto_wipe(&secret_text[0], secret_text.size());
    if (ok)
    {
        std::printf("key %s: secret in %s, public in %s\n", id_hex.c_str(), secret_path, public_path);
    }
    return ok;
}

static bool command_sign(const char* secret_path, const char* path)
{
    std::string secret_text;
    if (!read_file(secret_path, &secret_text))
    {
        return false;
    }
    uint8_t secret_key[SECRET_SIZE];
    std::string id_hex = field_get(secret_text, "key_id");
    bool decoded = hex_decode(field_get(secret_text, "secret"), secret_key, sizeof(secret_key));
    crypto_wipe(&secret_text[0], secret_text.size());
    if (!decoded || id_hex.size() != KEY_ID_SIZE * 2)
    {
        std::fprintf(stderr, "error: %s isn't a secret key file\n", secret_path);
        crypto_wipe(secret_key, sizeof(secret_key));
        return false;
    }

    std::string message;
    if (!read_file(path, &message))
    {
        crypto_wipe(secret_key, sizeof(secret_key));
        return false;
    }
    uint8_t signature[SIGNATURE_SIZE];
    crypto_eddsa_sign(signature, secret_key,
                      reinterpret_cast<const uint8_t*>(message.data()), message.size());
    crypto_wipe(secret_key, sizeof(secret_key));

    std::string text = "key_id=" + id_hex + "\nsignature=";
    hex_append(&text, signature, sizeof(signature));
    text += "\n";
    std::string sig_path = std::string(path) + ".sig";
    if (!write_file(sig_path.c_str(), text, 0644))
    {
        return false;
    }
    std::printf("signed %s (key %s)\n", path, id_hex.c_str());
    return true;
}

static bool command_verify(const char* public_path, const char* path)
{
    std::string public_text;
    std::string sig_text;
    std::string message;
    std::string sig_path = std::string(path) + ".sig";
    if (!read_file(public_path, &public_text) || !read_file(sig_path.c_str(), &sig_text) ||
        !read_file(path, &message))
    {
        return false;
    }
    uint8_t public_key[PUBLIC_SIZE];
    uint8_t signature[SIGNATURE_SIZE];
    if (!hex_decode(field_get(public_text, "public"), public_key, sizeof(public_key)))
    {
        std::fprintf(stderr, "error: %s isn't a public key file\n", public_path);
        return false;
    }
    if (!hex_decode(field_get(sig_text, "signature"), signature, sizeof(signature)))
    {
        std::fprintf(stderr, "error: %s isn't a signature file\n", sig_path.c_str());
        return false;
    }
    uint8_t key_id[KEY_ID_SIZE];
    key_id_compute(public_key, key_id);
    std::string id_hex;
    hex_append(&id_hex, key_id, sizeof(key_id));
    if (field_get(sig_text, "key_id") != id_hex)
    {
        std::fprintf(stderr, "error: %s was signed with another key (%s, not %s)\n",
                     path, field_get(sig_text, "key_id").c_str(), id_hex.c_str());
        return false;
    }
    if (crypto_eddsa_check(signature, public_key,
                           reinterpret_cast<const uint8_t*>(message.data()), message.size()) != 0)
    {
        std::fprintf(stderr, "error: bad signature on %s\n", path);
        return false;
    }
    std::printf("ok: %s (key %s)\n", path, id_hex.c_str());
    return true;
}

int main(int argc, char** argv)
{
    bool ok = false;
    if (argc == 4 && std::strcmp(argv[1], "keygen") == 0)
    {
        ok = command_keygen(argv[2], argv[3]);
    }
    else if (argc == 4 && std::strcmp(argv[1], "sign") == 0)
    {
        ok = command_sign(argv[2], argv[3]);
    }
    else if (argc == 4 && std::strcmp(argv[1], "verify") == 0)
    {
        ok = command_verify(argv[2], argv[3]);
    }
    else
    {
        std::fprintf(stderr,
                     "usage: index_sign keygen <secret key file> <public key file>\n"
                     "       index_sign sign   <secret key file> <file>\n"
                     "       index_sign verify <public key file> <file>\n");
    }
    return ok ? 0 : 1;
}
