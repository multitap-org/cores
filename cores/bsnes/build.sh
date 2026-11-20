#!/bin/sh
# Builds bsnes's libretro core with bsnes-libretro's top-level Makefile.
# Run by scripts/build-core.sh inside the (patched) source folder, with the
# toolchain in the environment (see that script).
set -eu

# The Makefile sets CFLAGS/CXXFLAGS itself (`:=`: the environment's are
# dropped; -O2 and -fPIC come from it) and appends to LDFLAGS (the
# environment's are kept). Android's target flags live in CC/CXX
# (toolchain.sh), so nothing the target needs is lost.
case "$PLATFORM" in
    windows) platform=win ;;
    *)       platform=unix ;;
esac
make platform="$platform" CC="${CC:-cc}" CXX="${CXX:-c++}" -j"$JOBS"

cp "bsnes_libretro.$LIB_EXT" "$OUT"
