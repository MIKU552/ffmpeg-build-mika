#!/bin/bash

# ==============================================================================
# Build Script for zlib (Data Compression Library)
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

echoSection "Building zlib"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/zlib"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/zlib"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://zlib.net/zlib-1.3.tar.gz
# Mirror: https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz
TARBALL="zlib-$VERSION.tar.gz"
URL="https://zlib.net/zlib-$VERSION.tar.gz"
MIRROR_URL="https://github.com/madler/zlib/releases/download/v$VERSION/zlib-$VERSION.tar.gz"

echo "Downloading source..."
if curl -L -f --retry 3 --connect-timeout 10 -o "$TARBALL" "$URL"; then
    echo "Download successful from zlib.net."
else
    echo "Primary download failed. Trying GitHub mirror..."
    download "$MIRROR_URL" "$TARBALL"
fi

# Unpack
SRC_DIR_NAME="zlib-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring zlib..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --prefix: Install location.
# --static: Build only static library (libz.a).
./configure \
    --prefix="$TOOL_DIR" \
    $CROSS_HOST_FLAG \
    --static

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "zlib Build Complete"