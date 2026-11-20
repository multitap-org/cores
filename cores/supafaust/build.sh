#!/bin/sh
# Builds Beetle Supafaust with its libretro Makefile; scripts/libretro-make.sh has the
# common part (platform, compilers, cross-compiling fixes).
set -eu
. "$REPO_ROOT/scripts/libretro-make.sh"
# Android: its config.h leaves out pthread affinity (Bionic has none) only
# when ANDROID is defined, as the NDK's own toolchains do. Not defined for
# every core: libretro-common's cdrom.c doesn't build with it.
if [ "$PLATFORM" = android ]; then
    export CFLAGS="$CFLAGS -DANDROID"
    export CXXFLAGS="$CXXFLAGS -DANDROID"
fi
libretro_make mednafen_supafaust
