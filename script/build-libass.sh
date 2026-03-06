#!/bin/bash

# ==============================================================================
# Build Script for libass (Portable ASS/SSA Subtitle Renderer)
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

echoSection "Building libass"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libass"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libass"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/libass/libass/releases/download/0.17.1/libass-0.17.1.tar.gz
TARBALL="libass-$VERSION.tar.gz"
URL="https://github.com/libass/libass/releases/download/$VERSION/libass-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libass-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring libass..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --enable-fontconfig: Use fontconfig for font selection (we built this).
# --enable-harfbuzz: Use harfbuzz for text shaping (we built this).
# --enable-fribidi: Use fribidi for BiDi support (we built this).
# --disable-require-system-font-provider: Don't force CoreText on macOS, prefer fontconfig.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --enable-fontconfig \
    --enable-harfbuzz \
    --enable-fribidi \
    --disable-require-system-font-provider

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libass Build Complete"