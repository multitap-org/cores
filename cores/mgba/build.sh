#!/bin/sh
# Builds mGBA's libretro core with its CMake build. Run by scripts/build-core.sh
# inside the source folder, with the toolchain in the environment (for Android
# also CMAKE_TOOLCHAIN_FILE, see scripts/toolchain.sh).
set -eu

# Only the libretro core, and none of the optional libraries (zip, PNG,
# SQLite, Lua, FFmpeg ...): the core needs only libc and libm, the same on
# every platform. CMAKE_POLICY_VERSION_MINIMUM: mGBA 0.10.5 asks for CMake 3.1,
# which CMake 4 refuses without it.
# With a toolchain file (Android) the flags are in it; CMake would also add the
# environment's a second time.
if [ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]; then
    unset CFLAGS CXXFLAGS LDFLAGS
fi
cmake -S . -B build-libretro -G Ninja \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_LIBRETRO=ON -DBUILD_QT=OFF -DBUILD_SDL=OFF -DBUILD_SHARED=OFF -DBUILD_STATIC=OFF \
    -DSKIP_LIBRARY=ON -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF -DUSE_EPOXY=OFF \
    -DUSE_DEBUGGERS=OFF -DUSE_GDB_STUB=OFF -DUSE_EDITLINE=OFF -DUSE_FFMPEG=OFF -DUSE_ZLIB=OFF \
    -DUSE_MINIZIP=OFF -DUSE_PNG=OFF -DUSE_LIBZIP=OFF -DUSE_SQLITE3=OFF -DUSE_ELF=OFF -DUSE_LUA=OFF \
    -DUSE_JSON_C=OFF -DUSE_LZMA=OFF -DUSE_DISCORD_RPC=OFF -DENABLE_SCRIPTING=OFF \
    -DBUILD_SUITE=OFF -DBUILD_CINEMA=OFF -DBUILD_EXAMPLE=OFF -DBUILD_UPDATER=OFF
cmake --build build-libretro --target mgba_libretro -j "$JOBS"

cp "build-libretro/mgba_libretro.$LIB_EXT" "$OUT"
