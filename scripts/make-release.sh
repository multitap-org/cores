#!/bin/sh
# Turns the CI's build artifacts into the files of one GitHub Release:
#   scripts/make-release.sh <artifacts folder> <output folder>
# The artifacts folder holds one folder per build, named <core>-<target>
# (target: linux-x86_64, linux-aarch64, windows-x86_64, android-arm64-v8a),
# each with that build's dist/ (<platform>/<library> and source/<tarball>).
#
# Output: per build a zip with the library inside
# (<file>_libretro-<target>-<commit7>.zip; never reused, the commit is in the
# name), the source tarballs, and manifest.cfg: one [<target>/<core>] block per
# build with what the downloader needs (name, version, license, free, size,
# SHA-256 ...). The server's publisher turns the manifest into signed indexes.
set -eu
. "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: make-release.sh <artifacts folder> <output folder>"
artifacts=$1
out=$2
mkdir -p "$out"
manifest="$out/manifest.cfg"
echo "# multitap cores: what one CI run built (scripts/make-release.sh)" > "$manifest"

sha256_of() {
    sha256sum "$1" | cut -d ' ' -f 1
}

size_of() {
    wc -c < "$1" | tr -d ' '
}

for dir in "$artifacts"/*/; do
    name=$(basename "$dir")
    # The web's archives aren't offered by the downloader: piccolo's browser
    # build makes its own (scripts/build-core.sh <core> web).
    case "$name" in
        *-web) continue ;;
    esac
    target=""
    for t in linux-x86_64 linux-aarch64 windows-x86_64 android-arm64-v8a; do
        case "$name" in
            *-"$t") target=$t ;;
        esac
    done
    [ -n "$target" ] || die "artifact $name has no known target"
    core=${name%-"$target"}
    cfg="$repo_root/cores/$core/core.cfg"
    [ -f "$cfg" ] || die "artifact $name: no $cfg"
    case "$(cfg_get "$cfg" type)" in
        main|legacy|experimental) ;;
        *) die "$cfg: type must be main, legacy or experimental" ;;
    esac

    file=$(cfg_get "$cfg" file)
    commit=$(cfg_get "$cfg" commit)
    short=$(echo "$commit" | cut -c 1-7)
    platform=${target%%-*}
    library_name="${file}_libretro.$(lib_ext "$platform")"
    library="$dir$platform/$library_name"
    source_name="$file-$commit.tar.gz"
    [ -f "$library" ] || die "artifact $name has no $platform/$library_name"
    [ -f "$dir/source/$source_name" ] || die "artifact $name has no source/$source_name"

    # Same bytes for the same library: fixed timestamp, no extra attributes.
    asset="${file}_libretro-$target-$short.zip"
    stage="$out/.stage-$name"
    rm -rf "$stage"
    mkdir -p "$stage"
    cp "$library" "$stage/$library_name"
    touch -d '1980-01-02 00:00:00 UTC' "$stage/$library_name"
    (cd "$stage" && zip -q -X -9 "$asset" "$library_name")
    mv "$stage/$asset" "$out/$asset"
    rm -rf "$stage"
    # Every build of a core brings the same source; the first copy is kept so
    # every block names the same file (tar.gz bytes can differ between runners).
    if [ ! -f "$out/$source_name" ]; then
        cp "$dir/source/$source_name" "$out/$source_name"
    fi

    {
        echo ""
        echo "[$target/$core]"
        echo "name=$(cfg_get "$cfg" name)"
        echo "core=$core"
        echo "file=$library_name"
        echo "version=$(cfg_get "$cfg" tag)"
        echo "commit=$commit"
        echo "license=$(cfg_get "$cfg" license)"
        echo "free=$(cfg_get "$cfg" free)"
        echo "type=$(cfg_get "$cfg" type)"
        echo "systems=$(cfg_get "$cfg" systems)"
        echo "asset=$asset"
        echo "size=$(size_of "$out/$asset")"
        echo "sha256=$(sha256_of "$out/$asset")"
        echo "library_size=$(size_of "$library")"
        echo "library_sha256=$(sha256_of "$library")"
        echo "source=$source_name"
        echo "source_sha256=$(sha256_of "$out/$source_name")"
    } >> "$manifest"
    echo "release: $target/$core -> $asset"
done
