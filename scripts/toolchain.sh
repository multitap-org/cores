# Sourced by build-core.sh: toolchain_setup <platform> exports the compiler
# for the target, the same toolchains piccolo is built with:
#   linux    this machine's cc (in CI: the Flatpak SDK, freedesktop 25.08, as piccolo's Flatpak)
#   windows  MSYS2 UCRT64's GCC, libgcc static (as piccolo's Windows build)
#   android  clang + the NDK's sysroot, API 28, lld, compiler-rt, 16 KB pages
#            (as piccolo's android/cmake/android-toolchain.cmake)
# Android needs ANDROID_NDK_ROOT. On x86_64 the NDK's own clang is used; on
# other hosts (Google only ships it for x86_64) a distro clang, PICCOLO_LLVM_ROOT
# (default /usr/lib/llvm-21), with the NDK's runtime libraries.

toolchain_setup() {
    HOST_CC=${HOST_CC:-cc}
    command -v "$HOST_CC" >/dev/null 2>&1 || HOST_CC=gcc
    export HOST_CC
    TOOLCHAIN_STRIP=strip

    case "$1" in
        linux)
            export CC=${CC:-cc}
            ;;
        windows)
            export CC=gcc
            # Only Windows' own DLLs: no libgcc / winpthread DLLs next to the core.
            export LDFLAGS="-static-libgcc -static"
            ;;
        android)
            toolchain_android
            ;;
        *)
            die "unknown platform: $1"
            ;;
    esac
}

toolchain_android() {
    api=28
    ndk=${ANDROID_NDK_ROOT:-$HOME/Android/ndk/android-ndk-r30}
    prebuilt="$ndk/toolchains/llvm/prebuilt/linux-x86_64"
    [ -f "$prebuilt/sysroot/usr/include/android/api-level.h" ] || die "no NDK sysroot under $prebuilt (set ANDROID_NDK_ROOT)"
    target="--target=aarch64-linux-android$api --sysroot=$prebuilt/sysroot"

    if "$prebuilt/bin/clang" --version >/dev/null 2>&1; then
        llvm="$prebuilt/bin"
        resource=""
    else
        llvm_root=${PICCOLO_LLVM_ROOT:-/usr/lib/llvm-21}
        [ -x "$llvm_root/bin/clang" ] || die "no clang in $llvm_root (set PICCOLO_LLVM_ROOT)"
        llvm="$llvm_root/bin"
        # The distro clang has no Android runtime libraries: a resource folder
        # of our own, its headers + the NDK's libraries (links, as in piccolo's
        # android-toolchain.cmake).
        resource_dir="$repo_root/build/android-clang-resource"
        mkdir -p "$resource_dir"
        [ -L "$resource_dir/include" ] || ln -s "$(ls -d "$llvm_root"/lib/clang/* | head -n 1)/include" "$resource_dir/include"
        [ -L "$resource_dir/lib" ] || ln -s "$(ls -d "$prebuilt"/lib/clang/* | head -n 1)/lib" "$resource_dir/lib"
        resource="-resource-dir=$resource_dir"
    fi

    export CC="$llvm/clang $target $resource"
    export CXX="$llvm/clang++ $target $resource"
    export AR="$llvm/llvm-ar"
    export CFLAGS="-fPIC -ffunction-sections -fdata-sections"
    export CXXFLAGS="$CFLAGS"
    # Bionic needs 16 KB page alignment on new devices (and Google Play from 2027).
    # Bionic has librt and libpthread inside libc; Makefiles written for glibc
    # still link -lrt -lpthread: empty archives of those names satisfy them.
    stubs="$repo_root/build/android-stubs"
    mkdir -p "$stubs"
    for stub in rt pthread; do
        [ -f "$stubs/lib$stub.a" ] || "$llvm/llvm-ar" rc "$stubs/lib$stub.a"
    done
    export LDFLAGS="-L$stubs -fuse-ld=lld -rtlib=compiler-rt -unwindlib=libunwind -static-libstdc++ -Wl,--build-id=sha1 -Wl,--no-undefined -Wl,-z,max-page-size=16384 -Wl,--gc-sections"
    TOOLCHAIN_STRIP="$llvm/llvm-strip"

    # The same for cores built with CMake (CMake reads CMAKE_TOOLCHAIN_FILE
    # from the environment): Linux + aarch64 rather than CMake's own Android
    # support, which looks for the NDK's x86_64-only compiler (as piccolo's
    # android-toolchain.cmake does).
    toolchain_file="$repo_root/build/android-toolchain.cmake"
    mkdir -p "$repo_root/build"
    cat > "$toolchain_file" <<CMAKE
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(ANDROID TRUE)
set(CMAKE_C_COMPILER "$llvm/clang")
set(CMAKE_CXX_COMPILER "$llvm/clang++")
set(CMAKE_C_COMPILER_TARGET aarch64-linux-android$api)
set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-android$api)
set(CMAKE_SYSROOT "$prebuilt/sysroot")
set(CMAKE_AR "$llvm/llvm-ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "$llvm/llvm-ranlib" CACHE FILEPATH "")
set(CMAKE_C_FLAGS_INIT "$CFLAGS $resource")
set(CMAKE_CXX_FLAGS_INIT "$CXXFLAGS $resource")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "$LDFLAGS")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "$LDFLAGS")
set(CMAKE_EXE_LINKER_FLAGS_INIT "$LDFLAGS")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
CMAKE
    export CMAKE_TOOLCHAIN_FILE="$toolchain_file"
}

toolchain_strip() {
    "$TOOLCHAIN_STRIP" --strip-unneeded "$1"
}
