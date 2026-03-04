#!/bin/bash

# ==============================================================================
# Build Script for libklvanc (KLV Ancillary Data)
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

echoSection "Building libklvanc"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libklvanc"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libklvanc"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/stoth68000/libklvanc/archive/refs/tags/vid.obe.1.6.0.tar.gz
TARBALL="libklvanc-$VERSION.tar.gz"
URL="https://github.com/stoth68000/libklvanc/archive/refs/tags/vid.obe.$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libklvanc-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Generating build system..."

# 【重点修改】绝对不要加 --clean --build 参数
# 之前的报错就是因为 autogen.sh (调用 autoreconf) 不支持这些参数
if [ -x "./autogen.sh" ]; then
    ./autogen.sh
    checkStatus $? "Autogen failed"
else
    echo "autogen.sh not found, running autoreconf manually..."
    autoreconf -fiv
    checkStatus $? "Autoreconf failed"
fi

echo "Configuring libklvanc..."
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libklvanc Build Complete"
