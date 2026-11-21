#!/bin/sh
# Builds DOSBox Pure with its own Makefile (not libretro's usual one).
#
# The Makefile sets LDFLAGS itself (`:=`: the environment's are dropped), so
# the toolchain's link flags (toolchain.sh: Windows' static libgcc /
# libstdc++ / winpthread, Android's lld, 16 KB pages and -lpthread stub)
# go in through LDLIBS, which only the link uses (the Makefile's own is
# -lpthread, kept).
# On arm64 (Linux, Android) the dynarec aligns its code cache to PAGESIZE,
# which the Makefile would take from the build machine's getconf: 16 KB
# fits 4 KB and 16 KB kernels alike (Android's new devices are 16 KB).
# Android's target flags live in CXX (toolchain.sh).
set -eu

cpuflags=""
case "$PLATFORM" in
    windows)
        set -- platform=windows
        ;;
    android)
        set --
        cpuflags="-DPAGESIZE=16384"
        ;;
    *)
        set --
        if [ "$(uname -m)" = aarch64 ]; then
            cpuflags="-DPAGESIZE=16384"
        fi
        ;;
esac
make "$@" CXX="${CXX:-c++}" MAKE_CPUFLAGS="$cpuflags" LDLIBS="${LDFLAGS:-} -lpthread" -j"$JOBS"

cp "dosbox_pure_libretro.$LIB_EXT" "$OUT"
