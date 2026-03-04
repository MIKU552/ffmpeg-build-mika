#!/bin/bash

# ==============================================================================
# Build Script for dav1d (AV1 Decoder)
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

echoSection "Building dav1d"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/dav1d"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/dav1d"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
TARBALL="dav1d-$VERSION.tar.gz"
URL="https://code.videolan.org/videolan/dav1d/-/archive/$VERSION/dav1d-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="dav1d-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Environment Setup (Meson)
# Ensure Meson/Ninja are available (via system or venv)
prepareMeson

# 5. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring dav1d..."

# Options:
# --libdir=lib: Force install to 'lib' (not lib64) to match our TOOL_DIR layout
# --default-library=static: We need static .a files for FFmpeg
# -Db_lto=true: Enable Link Time Optimization
# -Dbuildtype=release: Ensure maximum performance optimization
meson setup build \
    --prefix="$TOOL_DIR" \
    --libdir=lib \
    --default-library=static \
    -Dbuildtype=release \
    -Db_lto=true

checkStatus $? "Configuration failed"

# 6. Build
echo "Compiling..."
ninja -C build -j "$CPUS"
checkStatus $? "Build failed"

# 7. Install
echo "Installing..."
ninja -C build install
checkStatus $? "Installation failed"

echoSection "dav1d Build Complete"