#!/bin/bash

# ==============================================================================
# Build Script for libwebp (WebP Image Format)
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

echoSection "Building libwebp"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libwebp"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libwebp"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/webmproject/libwebp/archive/refs/tags/v1.3.2.tar.gz
TARBALL="libwebp-$VERSION.tar.gz"
URL="https://github.com/webmproject/libwebp/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libwebp-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring libwebp..."

# CMake Options:
# - BUILD_SHARED_LIBS=OFF: Static build.
# - WEBP_BUILD_LIBWEBPMUX=ON: Essential for Animated WebP support in FFmpeg.
# - WEBP_BUILD_LIBWEBPDEMUX=ON: Essential for reading WebP containers.
# - WEBP_BUILD_xxx=OFF: Disable command line tools (cwebp, dwebp, etc.) to save time.
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWEBP_BUILD_LIBWEBPMUX=ON \
    -DWEBP_BUILD_LIBWEBPDEMUX=ON \
    -DWEBP_BUILD_CWEBP=OFF \
    -DWEBP_BUILD_DWEBP=OFF \
    -DWEBP_BUILD_GIF2WEBP=OFF \
    -DWEBP_BUILD_IMG2WEBP=OFF \
    -DWEBP_BUILD_VWEBP=OFF \
    -DWEBP_BUILD_WEBPINFO=OFF \
    -DWEBP_BUILD_WEBPMUX=OFF \
    -DWEBP_BUILD_EXTRAS=OFF

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

echoSection "libwebp Build Complete"