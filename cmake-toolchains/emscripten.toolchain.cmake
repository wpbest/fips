#-------------------------------------------------------------------------------
#	emscripten.toolchain.cmake
#	Fips cmake toolchain file for cross-compiling to emscripten.
#-------------------------------------------------------------------------------

message("Target Platform: emscripten")

#
# FIXME FIXME FIXME:
#
#   emar currently has trouble using a non-standard .emscripten config
#   file: https://github.com/kripken/emscripten/issues/2886
#
#   once this is fixed, set the CMAKE_AR_FLAGS variable to
#   use the --em-config like the C/CXX compilers.
#

# emscripten SDK location
# (FIXME: the emscripten SDK version should be a cmake option)
# NOTE: on Windows, use the stable SDK, on other platforms, the bleeding-edge version
if (${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
    set(EMSC_EMSDK_DIRNAME "../fips-sdks/win/emsdk_portable/emscripten/1.27.0")
elseif (${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Darwin")
    set(EMSC_EMSDK_DIRNAME "../fips-sdks/osx/emsdk_portable/emscripten/incoming")
elseif (${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Linux")
    set(EMSC_EMSDK_DIRNAME "../fips-sdks/linux/emsdk_portable/emscripten/incoming")
endif()

set(FIPS_PLATFORM EMSCRIPTEN)
set(FIPS_PLATFORM_NAME "emsc")
set(FIPS_EMSCRIPTEN 1)
set(FIPS_POSIX 1)

# tweakable options 
option(FIPS_EMSCRIPTEN_USE_FS "Enable FS module on emscripten" OFF)

# enable the emscripten tracer if profiling is enabled
if (FIPS_PROFILING)
    set(EMSCRIPTEN_TRACING 1)
    set(EMSCRIPTEN_TRACING_OPTION "--tracing")
else()
    set(EMSCRIPTEN_TRACING 0)
    set(EMSCRIPTEN_TRACING_OPTION "")
endif()

# total memory is 128MB for main thread, and 16 MB for worker
# NOTE: USE_MEMORY_INIT_FILE has/had problems that the script is already starting but the MEM file isn't loaded yet(?)
# at least I'm having weird startup problems...
set(EMSCRIPTEN_TOTAL_MEMORY 134217728)
set(EMSCRIPTEN_TOTAL_MEMORY_WORKER 16777216)
set(EMSCRIPTEN_USE_MEMORY_INIT_FILE 1)
set(EMSCRIPTEN_LTO_LEVEL 1)
if (FIPS_EMSCRIPTEN_USE_FS)
    set(EMSCRIPTEN_NO_FILESYSTEM 0)
else()
    set(EMSCRIPTEN_NO_FILESYSTEM 1)
endif()

# disable closure for now, as long as ANGLE_instanced_array support is not fully supported in emscripten
set(EMSCRIPTEN_USE_CLOSURE 0)
set(EMSCRIPTEN_ASSERTIONS 0)
set(EMSCRIPTEN_OUTLINING_LIMIT 20000)

if (FIPS_COMPILE_VERBOSE)
    set(EMSCRIPTEN_BUILD_VERBOSE 1)
else()
    set(EMSCRIPTEN_BUILD_VERBOSE 0)
endif()

# exceptions on/off?
if (FIPS_EXCEPTIONS)
    message("C++ exceptions are enabled")
    set(FIPS_EMSC_EXCEPTION_FLAGS "")
    set(EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING 0)
else()
    message("C++ exceptions are disabled")
    set(FIPS_EMSC_EXCEPTION_FLAGS "-fno-exceptions")
    set(EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING 1)
endif()

message("EMSCRIPTEN_TOTAL_MEMORY: ${EMSCRIPTEN_TOTAL_MEMORY}")
message("EMSCRIPTEN_TOTAL_MEMORY_WORKER: ${EMSCRIPTEN_TOTAL_MEMORY_WORKER}")
message("EMSCRIPTEN_USE_MEMORY_INIT_FILE: ${EMSCRIPTEN_USE_MEMORY_INIT_FILE}")
message("EMSCRIPTEN_LTO_LEVEL: ${EMSCRIPTEN_LTO_LEVEL}")
message("EMSCRIPTEN_USE_CLOSURE: ${EMSCRIPTEN_USE_CLOSURE}")
message("EMSCRIPTEN_ASSERTIONS: ${EMSCRIPTEN_ASSERTIONS}")
message("EMSCRIPTEN_OUTLINING_LIMIT: ${EMSCRIPTEN_OUTLINING_LIMIT}")
message("EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING: ${EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING}")
message("EMSCRIPTEN_NO_FILESYSTEM: ${EMSCRIPTEN_NO_FILESYSTEM}")
message("EMSCRIPTEN_TRACING: ${EMSCRIPTEN_TRACING}")

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_VERSION 1)
set(COMPILING on)
set(CMAKE_CROSSCOMPILING TRUE)

# find the emscripten SDK and set the "EMSC_HAS_LOCAL_CONFIG" variable
macro(find_emscripten_sdk)
    # first check for the official EMSDK, this does not allow to override
    # the location of the .emscripten config file
    get_filename_component(EMSCRIPTEN_ROOT_PATH "${CMAKE_CURRENT_LIST_DIR}/../${EMSC_EMSDK_DIRNAME}" ABSOLUTE)
    if (EXISTS "${EMSCRIPTEN_ROOT_PATH}/emcc")
        message("Emscripten SDK found (emsdk): ${EMSCRIPTEN_ROOT_PATH}")
    else()
        message(FATAL_ERROR "Could not find emscripten SDK! Please run 'fips setup emscripten'!")
    endif()
endmacro()

# find the emscripten SDK
find_emscripten_sdk()

# Normalize, convert Windows backslashes to forward slashes or CMake will crash.
get_filename_component(EMSCRIPTEN_ROOT_PATH "${EMSCRIPTEN_ROOT_PATH}" ABSOLUTE)

# Find the .emscripten file and cache, this is either setup locally in the
# emscripten SDK (this is the preferred way and used by 'fips setup emscripten',
# but it's a brand new feature: https://github.com/juj/emsdk/issues/24)
# If an SDK-local .emscripten is not found, fall back to ~/.emscripten
get_filename_component(EMSCRIPTEN_DOT_FILE "${EMSCRIPTEN_ROOT_PATH}/../../.emscripten" ABSOLUTE)
if (EMSCRIPTEN_TRACING)
    # set a separate .emscripten_cache when tracing since this will use an 
    # instrumented dlmalloc.c
    get_filename_component(EMSCRIPTEN_CACHE "${EMSCRIPTEN_ROOT_PATH}/../../.emscripten_cache_tracing" ABSOLUTE)
else()
    get_filename_component(EMSCRIPTEN_CACHE "${EMSCRIPTEN_ROOT_PATH}/../../.emscripten_cache" ABSOLUTE)
endif()
if (EXISTS "${EMSCRIPTEN_DOT_FILE}")
    set(EMSCRIPTEN_CONFIG_OPTION "--em-config ${EMSCRIPTEN_DOT_FILE}")
    set(EMSCRIPTEN_CACHE_OPTION "--cache ${EMSCRIPTEN_CACHE}")
    message("Using local emscripten config at: ${EMSCRIPTEN_DOT_FILE}")
    message("Using local emscripten cache at: ${EMSCRIPTEN_CACHE}")
else()
    # no sdk-embedded config found, use the default (~/.emscripten and ~/.emscripten_cache)
    set(EMSCRIPTEN_CONFIG_OPTION "")
    set(EMSCRIPTEN_CACHE_OPTION "")
    message("Using global emscripten config at ~/.emscripten")
    message("Using global emscripten cache at ~/.emscripten_cache")
endif()

# tool suffic (.bat on windows)
if (CMAKE_HOST_WIN32)
    set(EMCC_SUFFIX ".bat")
else()
    set(EMCC_SUFFIX "")
endif()

include(CMakeForceCompiler)
CMAKE_FORCE_C_COMPILER("${CMAKE_C_COMPILER}" Clang)
CMAKE_FORCE_CXX_COMPILER("${CMAKE_CXX_COMPILER}" Clang)

# define configurations
set(CMAKE_CONFIGURATION_TYPES Debug Release)

# specify cross-compilers
set(CMAKE_C_COMPILER "${EMSCRIPTEN_ROOT_PATH}/emcc${EMCC_SUFFIX}" CACHE PATH "gcc" FORCE)
set(CMAKE_CXX_COMPILER "${EMSCRIPTEN_ROOT_PATH}/em++${EMCC_SUFFIX}" CACHE PATH "g++" FORCE)
set(CMAKE_AR "${EMSCRIPTEN_ROOT_PATH}/emar${EMCC_SUFFIX}" CACHE PATH "archive" FORCE)
set(CMAKE_LINKER "${EMSCRIPTEN_ROOT_PATH}/emcc${EMCC_SUFFIX}" CACHE PATH "linker" FORCE)
set(CMAKE_RANLIB "${EMSCRIPTEN_ROOT_PATH}/emranlib${EMCC_SUFFIX}" CACHE PATH "ranlib" FORCE)

# only search for libraries and includes in the toolchain
set(CMAKE_FIND_ROOT_PATH ${EMSCRIPTEN_ROOT_PATH})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_SYSTEM_INCLUDE_PATH "${EMSCRIPTEN_ROOT_PATH}/system/include")

# c++ compiler flags
set(CMAKE_CXX_FLAGS "${EMSCRIPTEN_CONFIG_OPTION} ${EMSCRIPTEN_CACHE_OPTION} ${EMSCRIPTEN_TRACING_OPTION} -std=c++11 -stdlib=libc++ ${FIPS_EMSC_EXCEPTION_FLAGS} -fstrict-aliasing -Wall -Wno-warn-absolute-paths -Wno-multichar -Wextra -Wno-unused-parameter -Wno-unknown-pragmas -Wno-ignored-qualifiers -Wno-long-long -Wno-overloaded-virtual -Wno-deprecated-writable-strings -Wno-unused-volatile-lvalue -Wno-inconsistent-missing-override")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -DNDEBUG")
set(CMAKE_CXX_FLAGS_DEBUG "-Os -g -D_DEBUG_ -D_DEBUG -DFIPS_DEBUG=1")
set(CMAKE_CXX_FLAGS_PROFILING "-Os --profiling")

# c compiler flags
set(CMAKE_C_FLAGS "${EMSCRIPTEN_CONFIG_OPTION} ${EMSCRIPTEN_CACHE_OPTION} ${EMSCRIPTEN_TRACING_OPTION} -fstrict-aliasing -Wall -Wno-warn-absolute-paths -Wextra -Wno-multichar -Wno-unused-parameter -Wno-unknown-pragmas -Wno-ignored-qualifiers -Wno-long-long -Wno-overloaded-virtual -Wno-deprecated-writable-strings -Wno-unused-volatile-lvalue")
set(CMAKE_C_FLAGS_RELEASE "-Os -DNDEBUG")
set(CMAKE_C_FLAGS_DEBUG "-Os -g -D_DEBUG_ -D_DEBUG -DFIPS_DEBUG=1")
set(CMAKE_C_FLAGS_PROFILING "-Os --profiling")

# linker flags
set(CMAKE_EXE_LINKER_FLAGS "${EMSCRIPTEN_CONFIG_OPTION} ${EMSCRIPTEN_CACHE_OPTION} ${EMSCRIPTEN_TRACING_OPTION} --memory-init-file ${EMSCRIPTEN_USE_MEMORY_INIT_FILE} -s ERROR_ON_UNDEFINED_SYMBOLS=1 -s TOTAL_MEMORY=${EMSCRIPTEN_TOTAL_MEMORY} -s DISABLE_EXCEPTION_CATCHING=${EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING} -s NO_FILESYSTEM=${EMSCRIPTEN_NO_FILESYSTEM}")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-Os --llvm-lto ${EMSCRIPTEN_LTO_LEVEL} -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE} -s ASM_JS=1 -s ASSERTIONS=${EMSCRIPTEN_ASSERTIONS} -s OUTLINING_LIMIT=${EMSCRIPTEN_OUTLINING_LIMIT} --closure ${EMSCRIPTEN_USE_CLOSURE}")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-Os -g -s ASM_JS=1 -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE}")
set(CMAKE_EXE_LINKER_FLAGS_PROFILING "--profiling -Os --llvm-lto ${EMSCRIPTEN_LTO_LEVEL} -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE} -s ASM_JS=1 -s ASSERTIONS=${EMSCRIPTEN_ASSERTIONS} -s OUTLINING_LIMIT=${EMSCRIPTEN_OUTLINING_LIMIT}")

# static library flags (for CMAKE_AR)
set(CMAKE_STATIC_LINKER_FLAGS "${EMSCRIPTEN_CONFIG_OPTION}")

# dynamic lib linker flags
set(CMAKE_SHARED_LINKER_FLAGS "-shared ${EMSCRIPTEN_CONFIG_OPTIONS} ${EMSCRIPTEN_CACHE_OPTION} ${EMSCRIPTEN_TRACING_OPTION} --memory-init-file 0 -s ERROR_ON_UNDEFINED_SYMBOLS=1 -s TOTAL_MEMORY=${EMSCRIPTEN_TOTAL_MEMORY_WORKER} -s BUILD_AS_WORKER=1 -s EXPORTED_FUNCTIONS=[\\\"_dowork\\\"] -s DISABLE_EXCEPTION_CATCHING=${EMSCRIPTEN_DISABLE_EXCEPTION_CATCHING} -s NO_FILESYSTEM=${EMSCRIPTEN_NO_FILESYSTEM}")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "-Os --llvm-lto ${EMSCRIPTEN_LTO_LEVEL} -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE} -s ASM_JS=1 -s ASSERTIONS=${EMSCRIPTEN_ASSERTIONS} -s OUTLINING_LIMIT=${EMSCRIPTEN_OUTLINING_LIMIT} --closure ${EMSCRIPTEN_USE_CLOSURE}")
set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "-Os -g -s ASM_JS=1 -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE} --closure 0")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILING "--profiling -Os --llvm-lto ${EMSCRIPTEN_LTO_LEVEL} -s VERBOSE=${EMSCRIPTEN_BUILD_VERBOSE} -s ASM_JS=1 -s ASSERTIONS=${EMSCRIPTEN_ASSERTIONS} -s OUTLINING_LIMIT=${EMSCRIPTEN_OUTLINING_LIMIT}")

# update cache variables for cmake gui
set(CMAKE_CONFIGURATION_TYPES "${CMAKE_CONFIGURATION_TYPES}" CACHE STRING "Config Type" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}" CACHE STRING "Generic C++ Compiler Flags" FORCE)
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}" CACHE STRING "C++ Debug Compiler Flags" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING "C++ Release Compiler Flags" FORCE)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}" CACHE STRING "Generic C Compiler Flags" FORCE)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}" CACHE STRING "C Debug Compiler Flags" FORCE)
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}" CACHE STRING "C Release Compiler Flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}" CACHE STRING "Generic Linker Flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG}" CACHE STRING "Debug Linker Flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}" CACHE STRING "Release Linker Flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}" CACHE STRING "Generic Shared Linker Flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG}" CACHE STRING "Debug Shared Linker Flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}" CACHE STRING "Release Shared Linker Flags" FORCE)
set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS}" CACHE STRING "Static Lib Flags" FORCE)

# set the build type to use
if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Compile Type" FORCE)
endif()
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release)

