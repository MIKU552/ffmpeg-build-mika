#!/bin/bash

# ==============================================================================
# Build Script for Snappy (Fast Compression/Decompression)
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

echoSection "Building Snappy"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/snappy"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/snappy"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/google/snappy/archive/refs/tags/1.1.10.tar.gz
TARBALL="snappy-$VERSION.tar.gz"
URL="https://github.com/google/snappy/archive/refs/tags/$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="snappy-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring Snappy..."
CMAKE_CROSS_FLAGS=""
if [ "$TARGET_OS" = "Windows" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SCRIPT_DIR/mingw64.cmake"
fi
# CMake Options:
# - BUILD_SHARED_LIBS=OFF: Static linking requirement.
# - CMAKE_INSTALL_LIBDIR=lib: Force install to 'lib' (avoids lib64 on some distros).
# - SNAPPY_BUILD_TESTS/BENCHMARKS=OFF: Speed up build.
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=OFF \
    $CMAKE_CROSS_FLAGS \
    -DSNAPPY_BUILD_TESTS=OFF \
    -DSNAPPY_BUILD_BENCHMARKS=OFF

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

echoSection "Snappy Build Complete"