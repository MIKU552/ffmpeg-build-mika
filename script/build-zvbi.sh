#!/bin/bash

# ==============================================================================
# Build Script for ZVBI (Raw VBI, Teletext, Closed Caption Decoding)
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

echoSection "Building ZVBI"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/zvbi"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/zvbi"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/zapping-vbi/zvbi/archive/refs/tags/v0.2.35.tar.gz
TARBALL="zvbi-$VERSION.tar.gz"
URL="https://github.com/zapping-vbi/zvbi/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="zvbi-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Generating build system..."
# ZVBI from git tags usually needs autogen
if [ -f "autogen.sh" ]; then
    chmod +x autogen.sh
    ./autogen.sh
    checkStatus $? "Autogen failed"
fi

echo "Configuring ZVBI..."

# CFLAGS:
# -D_GNU_SOURCE: Required for some Linux builds to expose libc features.
export CFLAGS="-D_GNU_SOURCE ${CFLAGS}"

# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --without-libpng: Disable PNG export support to reduce dependencies (FFmpeg doesn't strictly need it).
# --without-x: Disable X11 support (headless build).
# --disable-proxy: Disable proxy support to minimize networking code.
# LIBS="-liconv": Ensure it links against our static libiconv if needed.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --without-libpng \
    --without-x \
    --disable-proxy \
    --disable-nls

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "ZVBI Build Complete"