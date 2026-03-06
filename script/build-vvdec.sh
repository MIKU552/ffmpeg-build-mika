#!/bin/bash

# ==============================================================================
# Build Script for vvdec (H.266/VVC Decoder)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - H.266/VVC Decoding Support
#   - Link-Time Optimization (LTO) enabled
#   - PGO disabled (Not cost-effective for pure encoding workflows)
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

echoSection "Building vvdec"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/vvdec"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/vvdec"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
TARBALL="vvdec-${VERSION}.tar.gz"
URL="https://github.com/fraunhoferhhi/vvdec/archive/${VERSION}.tar.gz"

download "$URL" "$TARBALL"

SRC_DIR_NAME="vvdec-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"
cd "$SRC_DIR_NAME" || exit 1

# 4. Final Optimized Build
# ------------------------------------------------------------------------------
echoSection "Final Optimized Build"
CMAKE_CROSS_FLAGS=""
if [ "$TARGET_OS" = "Windows" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SCRIPT_DIR/mingw64.cmake"
fi
mkdir -p build-final
# Configure optimized build (LTO enabled, PGO removed)
cmake -S . -B build-final -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    $CMAKE_CROSS_FLAGS \
    -DVVDEC_ENABLE_LINK_TIME_OPT=ON

checkStatus $? "Final Config failed"

cmake --build build-final -j "$CPUS"
checkStatus $? "Final Build failed"

echo "Installing vvdec..."
cmake --install build-final
checkStatus $? "Final Install failed"

echoSection "vvdec Build Complete"