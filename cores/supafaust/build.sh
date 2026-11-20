#!/bin/sh
# Builds Beetle Supafaust with its libretro Makefile; scripts/libretro-make.sh has the
# common part (platform, compilers, cross-compiling fixes).
set -eu
. "$REPO_ROOT/scripts/libretro-make.sh"
libretro_make mednafen_supafaust
