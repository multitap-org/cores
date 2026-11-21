#!/bin/sh
# Builds Genesis Plus GX with its libretro Makefile (Makefile.libretro);
# scripts/libretro-make.sh has the common part.
set -eu
. "$REPO_ROOT/scripts/libretro-make.sh"
libretro_make genesis_plus_gx Makefile.libretro
