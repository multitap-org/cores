#!/bin/sh
# Builds Test libretro with its CMake build. It needs its submodules (Dear
# ImGui, imgui_sw, libretro-common, all MIT), which build-core.sh doesn't
# fetch: they're fetched here, at the commits the core pins. (The source
# archive in dist/source is the core's own repository, without them.)
# Not --recursive: imgui_sw's own submodules (its demo's, SSH URLs) aren't used.
# Android: the toolchain file (toolchain.sh, CMAKE_TOOLCHAIN_FILE) carries the flags.
set -eu

git submodule update --init --depth 1

if [ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]; then
    unset CFLAGS CXXFLAGS LDFLAGS
fi
cmake -S . -B build-libretro -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-libretro -j "$JOBS"

cp "build-libretro/test_libretro.$LIB_EXT" "$OUT"
