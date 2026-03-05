#!/bin/bash

# ==============================================================================
# Build Script for libbluray (Blu-ray Disc Playback Library)
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

echoSection "Building libbluray"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libbluray"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libbluray"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://download.videolan.org/pub/videolan/libbluray/1.3.4/libbluray-1.3.4.tar.bz2
TARBALL="libbluray-$VERSION.tar.bz2"
URL="https://download.videolan.org/pub/videolan/libbluray/$VERSION/libbluray-$VERSION.tar.bz2"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libbluray-src"
mkdir -p "$SRC_DIR_NAME"
# Use -xjf to handle .tar.bz2 directly
tar -xjf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring libbluray..."

# Flags:
# --disable-bdjava-jar: Disable BD-J (Java) support to avoid JDK dependency.
# --disable-examples: Skip building example binaries.
# --disable-doxygen-doc: Skip documentation generation.
# --enable-static / --disable-shared: Static linking requirement.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --disable-bdjava-jar \
    --disable-examples \
    --disable-doxygen-doc

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libbluray Build Complete"