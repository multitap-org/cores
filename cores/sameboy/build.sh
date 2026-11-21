#!/bin/sh
# Builds SameBoy's libretro core. Run by scripts/build-core.sh inside the
# source folder, with the toolchain in the environment (see that script).
set -eu

# The boot ROMs are assembled with rgbds and built into the core. They're
# built for this machine (rgbds and SameBoy's logo compressor run here; on
# Windows its Makefile wants an MSVC-style clang for that, NATIVE_CC), so
# the build machine's compiler is used (and the target flags dropped) even
# when cross compiling.
env -u CFLAGS -u CXXFLAGS -u LDFLAGS -u CC -u CXX -u AR \
    make bootroms RGBDS="$TOOLS_DIR/rgbds/" CC="$HOST_CC" NATIVE_CC="$HOST_CC" CONF=release

# The core itself, with SameBoy's own libretro Makefile. Called directly (not
# through `make libretro`) so CC/CFLAGS/LDFLAGS come from the environment.
# The web: its emscripten platform, a static archive (named .bc by the
# Makefile; an archive all the same). The Makefile doesn't notice changed
# flags, but the source is a fresh copy every time.
case "$PLATFORM" in
    windows) platform=win ;;
    web)     platform=emscripten ;;
    *)       platform=unix ;;
esac
if [ "$PLATFORM" = web ]; then
    make -C libretro platform=emscripten STATIC_LINKING=1 AR="$AR" \
        BOOTROMS_DIR="$PWD/build/bin/BootROMs" BIN="$PWD/build/bin" -j"$JOBS"
    cp build/bin/sameboy_libretro_emscripten.bc "$OUT"
    exit 0
fi
make -C libretro platform="$platform" \
    BOOTROMS_DIR="$PWD/build/bin/BootROMs" BIN="$PWD/build/bin" -j"$JOBS"

cp "build/bin/sameboy_libretro.$LIB_EXT" "$OUT"
