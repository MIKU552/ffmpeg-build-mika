#!/bin/bash

# ==============================================================================
# Build Script for LAME (MP3 Encoder)
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

echoSection "Building LAME (MP3)"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/lame"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/lame"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
TARBALL="lame-$VERSION.tar.gz"
URL="https://downloads.sourceforge.net/project/lame/lame/$VERSION/lame-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="lame-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring LAME..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --disable-frontend: Do not build the 'lame' executable, only the library (libmp3lame).
# --enable-nasm: Enable assembly optimizations (requires nasm).
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --disable-frontend \
    --enable-nasm

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "LAME Build Complete"