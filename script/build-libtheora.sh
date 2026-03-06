#!/bin/bash

# ==============================================================================
# Build Script for libtheora (Theora Video Compression)
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

echoSection "Building libtheora"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libtheora"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libtheora"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.xz
# Note: Xiph sometimes uses http, curl will follow redirects if needed.
TARBALL="libtheora-$VERSION.tar.xz"
URL="http://downloads.xiph.org/releases/theora/libtheora-$VERSION.tar.xz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libtheora-src"
mkdir -p "$SRC_DIR_NAME"
# Use -xf to handle .xz automatically
tar -xf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring libtheora..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --disable-*test: Skip building test binaries.
# --disable-doc / --disable-examples: Skip documentation and examples.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --disable-oggtest \
    --disable-vorbistest \
    --disable-sdltest \
    --disable-doc \
    --disable-examples

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libtheora Build Complete"