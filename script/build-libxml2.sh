#!/bin/bash

# ==============================================================================
# Build Script for libxml2 (XML Parser)
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

echoSection "Building libxml2"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libxml2"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libxml2"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.11.5/libxml2-v2.11.5.tar.gz
TARBALL="libxml2-$VERSION.tar.gz"
URL="https://gitlab.gnome.org/GNOME/libxml2/-/archive/v$VERSION/libxml2-v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libxml2-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Generate Build System
cd "$SRC_DIR_NAME" || exit 1

# If downloading from Git tags, 'configure' script is often missing.
if [ ! -f "configure" ]; then
    echo "configure script not found. Running autogen.sh..."
    # NOCONFIGURE=YES: Don't run configure yet, just generate it.
    # ACLOCAL_PATH: Ensure it finds our toolchain's macros.
    export ACLOCAL_PATH="$TOOL_DIR/share/aclocal"
    NOCONFIGURE=YES ./autogen.sh
    checkStatus $? "Autogen failed"
fi

# 5. Configure
echo "Configuring libxml2..."

# ==============================================================================
# Cross-Compile Autotools Setup
# ==============================================================================
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi

./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --without-python \
    --with-ftp=no \
    --with-http=no \
    --with-legacy=no \
    --without-lzma \
    --with-zlib="$TOOL_DIR"

checkStatus $? "Configuration failed"

# 6. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 7. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libxml2 Build Complete"