#!/bin/sh
# Builds piccobots with its CMake build. The source comes without its
# submodule, so libretro.h comes from this repository's deps/libretro-common.
# Android: the toolchain file (toolchain.sh, CMAKE_TOOLCHAIN_FILE) carries the
# flags. The web: a static archive (PICCOBOTS_STATIC) with emcmake, -pthread
# from CXXFLAGS (toolchain.sh).
set -eu

if [ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]; then
    unset CFLAGS CXXFLAGS LDFLAGS
fi
static=OFF
configure=cmake
if [ "$PLATFORM" = web ]; then
    static=ON
    configure="emcmake cmake"
fi
$configure -S . -B build-libretro -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DPICCOBOTS_STATIC="$static" -DPICCOBOTS_BUILD_TESTS=OFF \
    -DPICCOBOTS_LIBRETRO_INCLUDE="$REPO_ROOT/deps/libretro-common/include"
cmake --build build-libretro -j "$JOBS"

cp "build-libretro/piccobots_libretro.$LIB_EXT" "$OUT"
