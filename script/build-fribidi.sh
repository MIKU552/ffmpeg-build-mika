#!/bin/bash

# ==============================================================================
# Build Script for FriBidi (Unicode Bidirectional Algorithm)
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

echoSection "Building FriBidi"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/fribidi"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/fribidi"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz
TARBALL="fribidi-$VERSION.tar.xz"
URL="https://github.com/fribidi/fribidi/releases/download/v$VERSION/fribidi-$VERSION.tar.xz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="fribidi-src"
mkdir -p "$SRC_DIR_NAME"
# Use -xf to handle .xz automatically
tar -xf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring FriBidi..."

# Flags:
# --disable-docs: Skip documentation build.
# --disable-debug: Release build without debug symbols.
# --enable-static / --disable-shared: Static linking requirement.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --disable-docs \
    --disable-debug

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "FriBidi Build Complete"