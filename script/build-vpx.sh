#!/bin/bash

# ==============================================================================
# Build Script for libvpx (VP8/VP9 Video Codec)
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

echoSection "Building libvpx (VP8/VP9)"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/vpx"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/vpx"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/webmproject/libvpx/archive/v1.13.1.tar.gz
# Note: GitHub archives for libvpx usually drop the 'v' in the folder structure or not,
# so we rely on strip-components to be safe.
TARBALL="vpx-$VERSION.tar.gz"
URL="https://github.com/webmproject/libvpx/archive/$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="vpx-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring libvpx..."

# Detect Architecture
ARCH=$(uname -m)
NASM_FLAG=""

# Only enable NASM on x86_64. On ARM64 (Apple Silicon), libvpx uses NEON automatically.
if [ "$ARCH" = "x86_64" ]; then
    echo "x86_64 architecture detected: Enabling NASM."
    NASM_FLAG="--as=nasm"
else
    echo "Non-x86 architecture detected ($ARCH): NASM disabled."
fi
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-vp9-highbitdepth: Enable 10/12-bit encoding support (Crucial for HDR).
# --enable-pic: Position Independent Code (good practice for static libs).
# --disable-examples/tools/docs: Speed up build.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --disable-examples \
    --disable-tools \
    --disable-docs \
    --disable-unit-tests \
    --enable-vp9-highbitdepth \
    --enable-pic \
    $NASM_FLAG

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libvpx Build Complete"
