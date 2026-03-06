#!/bin/bash

# ==============================================================================
# Build Script for Fontconfig
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

echoSection "Building Fontconfig"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/fontconfig"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/fontconfig"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.14.2/fontconfig-2.14.2.tar.xz
TARBALL="fontconfig-$VERSION.tar.xz"
URL="https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/$VERSION/fontconfig-$VERSION.tar.xz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="fontconfig-src"
mkdir -p "$SRC_DIR_NAME"
tar -xvf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring Fontconfig..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-libxml2: Use libxml2 for parsing configuration (we built this statically).
# --disable-docs: Skip documentation build to avoid docbook dependencies.
# --enable-iconv: Ensure character set conversion support.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --enable-libxml2 \
    --enable-iconv \
    --disable-docs

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "Fontconfig Build Complete"