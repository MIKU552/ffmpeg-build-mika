#!/bin/bash

# ==============================================================================
# Build Script for SDL2 (Simple DirectMedia Layer)
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

echoSection "Building SDL2"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/sdl"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/sdl"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz
# Fallback: https://www.libsdl.org/release/SDL2-$VERSION.tar.gz
TARBALL="SDL2-$VERSION.tar.gz"
URL="https://github.com/libsdl-org/SDL/releases/download/release-$VERSION/SDL2-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="sdl-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring SDL2..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --enable-system-iconv=no: Use SDL's internal iconv implementation (safer for static builds).
# --disable-rpath: Don't hardcode runtime library search paths.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --enable-system-iconv=no \
    --disable-rpath

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "SDL2 Build Complete"