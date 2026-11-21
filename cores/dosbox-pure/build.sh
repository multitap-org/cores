#!/bin/sh
# Builds DOSBox Pure with its own Makefile (not libretro's usual one).
#
# The Makefile sets LDFLAGS itself (`:=`: the environment's are dropped) and
# adds CPUFLAGS (MAKE_CPUFLAGS) to both compiling and linking, so what the
# target needs from us goes there: on Windows libgcc / libstdc++ /
# winpthread linked in (only Windows' own DLLs next to the core).
# On arm64 (Linux, Android) the dynarec aligns its code cache to PAGESIZE,
# which the Makefile would take from the build machine's getconf: 16 KB
# fits 4 KB and 16 KB kernels alike (Android's new devices are 16 KB).
# Android's target flags live in CXX (toolchain.sh).
set -eu

cpuflags=""
case "$PLATFORM" in
    windows)
        set -- platform=windows
        cpuflags="-static-libgcc -static-libstdc++ -static"
        ;;
    android)
        set --
        cpuflags="-DPAGESIZE=16384 -fPIC"
        ;;
    *)
        set --
        if [ "$(uname -m)" = aarch64 ]; then
            cpuflags="-DPAGESIZE=16384"
        fi
        ;;
esac
make "$@" CXX="${CXX:-c++}" MAKE_CPUFLAGS="$cpuflags" -j"$JOBS"

cp "dosbox_pure_libretro.$LIB_EXT" "$OUT"
