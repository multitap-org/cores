#!/bin/sh
# Builds Snes9x with its libretro Makefile (libretro/). Desktop and Android:
# scripts/libretro-make.sh's common part. The web: the emscripten platform.
set -eu

if [ "$PLATFORM" = web ]; then
    # STATIC_LINKING=0 on make's command line (it wins over the emscripten
    # platform's =1): with =1 the Makefile leaves libretro-common's file
    # streams and VFS out of the archive, for RetroArch's own copy. piccolo
    # has none, so the core keeps its own. Still an archive
    # (STATIC_LINKING_LINK), named .bc by the Makefile.
    make -C libretro platform=emscripten STATIC_LINKING=0 AR="$AR" -j"$JOBS"
    cp libretro/snes9x_libretro_emscripten.bc "$OUT"
    exit 0
fi

. "$REPO_ROOT/scripts/libretro-make.sh"
cd libretro
libretro_make snes9x
