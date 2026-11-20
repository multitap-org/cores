#!/bin/sh
# Builds one core for one platform:
#   scripts/build-core.sh <core> <platform>
#   platform: linux (this machine's arch), windows (from MSYS2 UCRT64), android (arm64-v8a)
# Output: dist/<platform>/<file>_libretro.<ext> (+ .sha256), and the exact source
# as dist/source/<file>-<commit>.tar.gz (the source offer for GPL cores).
#
# The core's source is fetched at the commit in cores/<core>/core.cfg, our
# patches applied (cores/<core>/*.patch), and built by cores/<core>/build.sh, which gets in its environment:
#   PLATFORM, LIB_EXT, OUT (file to write), TOOLS_DIR, HOST_CC, JOBS, REPO_ROOT,
#   and CC/CXX/AR/CFLAGS/CXXFLAGS/LDFLAGS for the target (see toolchain.sh).
set -eu
. "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: build-core.sh <core> <platform>"
core=$1
platform=$2
cfg="$repo_root/cores/$core/core.cfg"
[ -f "$cfg" ] || die "no $cfg"

file=$(cfg_get "$cfg" file)
repo=$(cfg_get "$cfg" repo)
commit=$(cfg_get "$cfg" commit)
tools=$(cfg_get "$cfg" tools)

"$repo_root/scripts/tools.sh" $tools

# Source at the pinned commit (a fresh copy every time: no leftovers from an
# earlier build or another platform).
src="$repo_root/build/src/$core-$platform"
rm -rf "$src"
mkdir -p "$src"
git -C "$src" init -q
git -C "$src" fetch -q --depth 1 "$repo" "$commit"
git -C "$src" checkout -q FETCH_HEAD

# Our patches (cores/<core>/*.patch, in name order), committed so the source
# archive below is exactly what gets built.
patches=$(ls "$repo_root/cores/$core/"*.patch 2>/dev/null || true)
if [ -n "$patches" ]; then
    for patch in $patches; do
        git -C "$src" apply --index "$patch" || die "$patch doesn't apply"
    done
    git -C "$src" -c user.name=multitap -c user.email=cores@multitap.invalid \
        commit -q -m "Multitap patches: $(cd "$repo_root/cores/$core" && ls *.patch | tr '\n' ' ')"
fi

mkdir -p "$repo_root/dist/source"
git -C "$src" archive --format=tar.gz --prefix="$file-$commit/" \
    -o "$repo_root/dist/source/$file-$commit.tar.gz" HEAD

. "$repo_root/scripts/toolchain.sh"
toolchain_setup "$platform"

out_dir="$repo_root/dist/$platform"
mkdir -p "$out_dir"
export PLATFORM="$platform"
export REPO_ROOT="$repo_root"
export LIB_EXT=$(lib_ext "$platform")
export OUT="$out_dir/${file}_libretro.$LIB_EXT"
export TOOLS_DIR="$repo_root/build/host-tools"
export JOBS=$(jobs_count)

(cd "$src" && sh "$repo_root/cores/$core/build.sh")

[ -f "$OUT" ] || die "$core didn't produce $OUT"
toolchain_strip "$OUT"
(cd "$out_dir" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")
echo "built $OUT"
