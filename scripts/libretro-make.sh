# Sourced by a core's build.sh: libretro_make <file> builds a core with its
# libretro Makefile (libretro's usual one: platform=unix / win, TARGET
# <file>_libretro.<ext> in the source folder) and copies it to $OUT.
#
# Our toolchain comes in through CC / CXX (Android's target flags live there,
# toolchain.sh), LDFLAGS from the environment (these Makefiles append to it).
# The Makefiles look at `uname` for the architecture; when cross compiling
# for Android that's the build machine's, so IS_X86 is forced off.

libretro_make() {
    file=$1
    case "$PLATFORM" in
        windows) make_platform=win ;;
        *)       make_platform=unix ;;
    esac
    set -- platform="$make_platform" CC="${CC:-cc}" CXX="${CXX:-c++}"
    if [ "$PLATFORM" = android ]; then
        set -- "$@" IS_X86=0 AR="$AR"
    fi
    make "$@" -j"$JOBS"
    cp "${file}_libretro.$LIB_EXT" "$OUT"
}
