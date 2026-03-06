#!/bin/bash

# ==============================================================================
# Build Script for whisper.cpp (Port of OpenAI's Whisper model)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
# ==============================================================================

# 1. Argument Processing
echo "Arguments: $@"
SCRIPT_DIR="$1"
SOURCE_DIR="$2"
TOOL_DIR="$3"
CPUS="$4"

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

echoSection "Building whisper.cpp"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/whisper"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)
echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/whispercpp"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/ggerganov/whisper.cpp/archive/refs/tags/v1.5.4.tar.gz
TARBALL="whispercpp-$VERSION.tar.gz"
URL="https://github.com/ggerganov/whisper.cpp/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="whispercpp-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring whisper.cpp..."
CMAKE_CROSS_FLAGS=""
if [ "$TARGET_OS" = "Windows" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SCRIPT_DIR/mingw64.cmake"
fi
# CMake Options:
# - BUILD_SHARED_LIBS=OFF: Static linking.
# - WHISPER_BUILD_EXAMPLES/TESTS=OFF: Speed up build, we only need the lib.
# - CMAKE_POSITION_INDEPENDENT_CODE=ON: Required for linking into FFmpeg (shared or static).
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    $CMAKE_CROSS_FLAGS \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

# 7. Post-Install Fix for Static Linking
# ------------------------------------------------------------------------------
# whisper.cpp's architecture splits ggml into multiple sub-libraries (cpu, metal, blas).
# The generated whisper.pc often fails to list these, causing linker errors in FFmpeg.

echoSection "Patching whisper.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/whisper.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    # 1. Detect which GGML sub-libraries were actually built
    # Recent versions produce libggml.a, libggml-cpu.a, libggml-metal.a, etc.
    GGML_DEPS="-lggml"
    
    # Check for specific sub-backends in the lib folder
    for sublib in ggml-cpu ggml-metal ggml-blas ggml-base; do
        if [ -f "$TOOL_DIR/lib/lib${sublib}.a" ]; then
            echo "Detected sub-library: lib${sublib}.a"
            GGML_DEPS="$GGML_DEPS -l${sublib}"
        fi
    done

    # 2. Add OS-specific system dependencies
    SYS_LIBS=""
    if [ "$OS_NAME" = "Darwin" ]; then
        # macOS: Needs Apple frameworks for Metal/Accelerate support
        SYS_LIBS="-lc++ -framework Accelerate -framework Metal -framework Foundation -framework CoreGraphics"
    elif [ "$OS_NAME" = "Linux" ]; then
        # Linux: Usually needs libstdc++ and OpenMP
        SYS_LIBS="-lstdc++ -fopenmp"
    fi
    
    # Common system libs
    SYS_LIBS="$SYS_LIBS -lm -lpthread"

    # 3. Inject dependencies into the .pc file
    # We replace "-lwhisper" with "-lwhisper -lggml -lggml-cpu ... -framework ..."
    FULL_LIBS="$GGML_DEPS $SYS_LIBS"
    
    echo "Injecting dependencies: $FULL_LIBS"
    
    # Use sed to append libs. We look for 'Libs:' or 'Libs.private:' line.
    # Note: Simplest way is to append to the existing library flag.
    run_sed "s/-lwhisper/-lwhisper $FULL_LIBS/g" "$PC_FILE"
    
    checkStatus $? "Patching whisper.pc failed"
else
    echo "Warning: whisper.pc not found. FFmpeg might fail to find whisper."
fi

echoSection "whisper.cpp Build Complete"