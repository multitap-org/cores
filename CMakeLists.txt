# The tools: host-libretro's libretro_core_info (the cores are checked with it)
# and index_sign (signs the core indexes). libretro_core_info is
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

foreach(_dep hosts-common/CMakeLists.txt host-libretro/CMakeLists.txt libretro-common/include/libretro.h
             monocypher/src/monocypher.c)
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

# Monocypher (deps/monocypher, BSD-2-Clause or CC0), the same one frontends-common
# uses: index_sign signs the core indexes with it, piccolo verifies with it.
add_library(multitap_dep_monocypher STATIC deps/monocypher/src/monocypher.c)
target_include_directories(multitap_dep_monocypher SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/deps/monocypher/src")

add_executable(index_sign tools/index_sign.cpp)
target_link_libraries(index_sign PRIVATE multitap_dep_monocypher)
multitap_set_project_flags(index_sign)
