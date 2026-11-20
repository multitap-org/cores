# cores

The libretro cores Multitap's frontends (piccolo) distribute: which cores,
which version, built how, under what license. Not the cores' source: that
stays upstream; our changes are patches here (`cores/<core>/*.patch`, applied
before building and part of the source archive).

- `cores/<core>/core.cfg`: upstream repository, tag + pinned commit, license,
  `free` (true = free-licensed, can ship in store builds; false = non-commercial
  or similar, offered only by the downloader of non-store builds), build tools,
  smoke-test content.
- `cores/<core>/*.patch`: our changes to the core (Multitap's API additions,
  `libretro_extensions.h` from host-libretro), applied in name order.
- `cores/<core>/build.sh`: how the core is built (the toolchain comes from
  `scripts/toolchain.sh`).
- `scripts/build-core.sh <core> <linux|windows|android>`: fetches the source at
  the pinned commit, builds, writes `dist/<platform>/<core>_libretro.<ext>`,
  its `.sha256`, and the exact source to `dist/source/`.
- `scripts/smoke.sh <core> <platform>`: loads the core with host-libretro's
  `libretro_core_info` (the host piccolo uses; built from `deps/`) and runs 300
  frames of our own test content (`smoke/`); on Android it checks arm64 and
  16 KB page alignment.
- `scripts/make-release.sh`: turns the CI's builds into a GitHub Release
  (deterministic zips, the sources, `manifest.cfg` with sizes and SHA-256).
- `tools/index_sign.cpp`: keygen / sign / verify for the downloader's indexes
  (Monocypher EdDSA, the same Monocypher piccolo verifies with). The server's
  publisher (private repo) pulls the latest release, checks it, writes one
  signed index per target to cores.get-piccolo.app.
- `keys/current.public`: the public key the indexes at
  https://cores.get-piccolo.app are signed with (key_id 20ad1a6e8a2bfdca).
  Check one: `index_sign verify keys/current.public linux-x86_64.cfg` (with its
  `.sig` next to it). piccolo will carry it (plus a "next" key for rotation).
- CI (`.github/workflows/build.yml`): piccolo's toolchains. Linux in the
  freedesktop 25.08 Flatpak SDK (x86_64, aarch64), Windows with MSYS2 UCRT64,
  Android with the NDK (API 28, 16 KB pages).

Locally (Linux):

```sh
git clone --recursive https://github.com/multitap-org/cores.git
scripts/build-core.sh sameboy linux && scripts/smoke.sh sameboy linux
ANDROID_NDK_ROOT=~/Android/ndk/android-ndk-r30 scripts/build-core.sh sameboy android
```

The scripts are MIT (LICENSE); every core keeps its own license.
