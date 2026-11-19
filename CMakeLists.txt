# The tools the cores are checked with: host-libretro's libretro_core_info,
# built from the same libraries piccolo uses (submodules in deps/). No SDL, no
# GUI. Build:
#   cmake -S . -B build/tools -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/tools

cmake_minimum_required(VERSION 3.25)
project(multitap_cores LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(MULTITAP_WARNINGS_AS_ERRORS "Treat warnings in our own code as errors" OFF)
option(MULTITAP_SANITIZE           "Build our own code with ASan + UBSan"      OFF)
set(MULTITAP_BUILD_TESTS OFF)

foreach(_dep hosts-common/CMakeLists.txt host-libretro/CMakeLists.txt libretro-common/include/libretro.h)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/deps/${_dep}")
        message(FATAL_ERROR "deps/${_dep} is missing. Run: git submodule update --init --recursive")
    endif()
endforeach()

# libretro API header. Only include/libretro*.h is used.
add_library(libretro_api INTERFACE)
target_include_directories(libretro_api SYSTEM INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/deps/libretro-common/include")

set(MULTITAP_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps")
add_subdirectory(deps/hosts-common)
add_subdirectory(deps/host-libretro)
