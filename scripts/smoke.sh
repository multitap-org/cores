#!/bin/sh
# Checks a built core:
#   scripts/smoke.sh <core> <platform>
# linux / windows: loads it with host-libretro's libretro_core_info (the same
# host piccolo uses) and runs 300 frames of our own test content for its
# system (smoke/<smoke>.asm); every frame must produce video.
# android: can't run here; checks it's an arm64 ELF with 16 KB aligned segments.
set -eu
. "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: smoke.sh <core> <platform>"
core=$1
platform=$2
cfg="$repo_root/cores/$core/core.cfg"
file=$(cfg_get "$cfg" file)
smoke=$(cfg_get "$cfg" smoke)
lib="$repo_root/dist/$platform/${file}_libretro.$(lib_ext "$platform")"
[ -f "$lib" ] || die "no $lib (build it first)"

if [ "$platform" = android ]; then
    readelf=$(command -v llvm-readelf || command -v readelf) || die "no readelf"
    "$readelf" -h "$lib" | grep -q 'AArch64' || die "$lib isn't arm64"
    # Every LOAD segment aligned to 16 KB (0x4000) or more (Align is the last column).
    for align in $("$readelf" -lW "$lib" | awk '$1 == "LOAD" { print $NF }'); do
        [ "$(printf '%d' "$align")" -ge 16384 ] || die "$lib has a LOAD segment aligned to $align (< 16 KB)"
    done
    echo "ok: $lib is arm64 with 16 KB aligned segments"
    exit 0
fi

# libretro_core_info, built from deps/ (cached in build/tools).
tools_build="$repo_root/build/tools"
if [ ! -f "$tools_build/build.ninja" ]; then
    cmake -S "$repo_root" -B "$tools_build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
fi
cmake --build "$tools_build" --target libretro_core_info >/dev/null
core_info="$tools_build/deps/host-libretro/libretro_core_info"

# Test content.
content=""
case "$smoke" in
    gb)
        "$repo_root/scripts/tools.sh" rgbds
        rgbds="$repo_root/build/host-tools/rgbds"
        work="$repo_root/build/smoke"
        mkdir -p "$work"
        "$rgbds/rgbasm" -o "$work/gb.o" "$repo_root/smoke/gb.asm"
        "$rgbds/rgblink" -o "$work/gb.gb" "$work/gb.o"
        "$rgbds/rgbfix" -v -p 0xFF -t SMOKE "$work/gb.gb"
        content="$work/gb.gb"
        ;;
    "") ;;
    *) die "unknown smoke content: $smoke" ;;
esac

run_dir="$repo_root/build/smoke/run-$core"
rm -rf "$run_dir"
mkdir -p "$run_dir/system" "$run_dir/save"
log="$run_dir/log.txt"
frames=300
if ! "$core_info" --frames "$frames" --system "$run_dir/system" --save "$run_dir/save" \
        "$lib" $content > "$log" 2>&1; then
    cat "$log"
    die "libretro_core_info failed for $lib"
fi
summary=$(grep 'Ran [0-9]* frames' "$log" || true)
echo "$summary"
case "$summary" in
    "Ran $frames frames: $frames video frames"*|*"Ran $frames frames: $frames video frames"*) ;;
    *) cat "$log"; die "$lib didn't produce a video frame for every frame" ;;
esac
grep -q ' 0 video errors' "$log" || { cat "$log"; die "video errors"; }
echo "ok: $lib"
