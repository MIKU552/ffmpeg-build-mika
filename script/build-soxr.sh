#!/bin/bash

# ==============================================================================
# Build Script for SoXR (The SoX Resampler library)
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

echoSection "Building SoXR"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/soxr"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/soxr"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://sourceforge.net/projects/soxr/files/soxr-0.1.3-Source.tar.xz/download
TARBALL="soxr-$VERSION.tar.xz"
URL="https://sourceforge.net/projects/soxr/files/soxr-$VERSION-Source.tar.xz/download"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="soxr-src"
mkdir -p "$SRC_DIR_NAME"
# Use -xJf for .tar.xz
tar -xJf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring SoXR..."

# CMake Options:
# - CMAKE_INSTALL_LIBDIR=lib: Force install to 'lib' (not lib64).
# - BUILD_SHARED_LIBS=OFF: Static linking.
# - WITH_OPENMP=OFF: Disable OpenMP to avoid libgomp dependencies (portability).
# - BUILD_TESTS=OFF: Speed up build.
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_OPENMP=OFF \
    -DBUILD_TESTS=OFF \
    -DWITH_PVRG=OFF \
    -DWITH_LSR=OFF

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

echoSection "SoXR Build Complete"