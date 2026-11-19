#!/bin/sh
# Builds the tools some cores need at build time, for this machine, into
# build/host-tools/<tool>/. Pinned versions, built from source, so every
# platform (Flatpak SDK, MSYS2, the NDK build) gets the same ones.
#   scripts/tools.sh rgbds
set -eu
. "$(dirname "$0")/common.sh"

tools_dir="$repo_root/build/host-tools"
mkdir -p "$tools_dir"

for tool in "$@"; do
    case "$tool" in
        rgbds)
            # Game Boy assembler: SameBoy's boot ROMs, the smoke-test ROM.
            if [ -x "$tools_dir/rgbds/rgbasm" ] || [ -x "$tools_dir/rgbds/rgbasm.exe" ]; then
                continue
            fi
            src="$repo_root/build/src/rgbds"
            rm -rf "$src"
            git clone -q --depth 1 --branch v1.0.1 https://github.com/gbdev/rgbds.git "$src"
            cmake -S "$src" -B "$src/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
            cmake --build "$src/build"
            # rgbds' build puts the programs in its source folder.
            mkdir -p "$tools_dir/rgbds"
            for exe in rgbasm rgblink rgbfix rgbgfx; do
                cp "$src/$exe"* "$tools_dir/rgbds/"
            done
            ;;
        "") ;;
        *) die "unknown tool: $tool" ;;
    esac
done
