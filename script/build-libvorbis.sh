#!/bin/bash

# ==============================================================================
# Build Script for libvorbis (Vorbis Audio Codec)
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

echoSection "Building libvorbis"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libvorbis"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

OS_NAME=$(uname -s)

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libvorbis"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz
TARBALL="libvorbis-$VERSION.tar.gz"
URL="https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libvorbis-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Patching (macOS Specific)
cd "$SRC_DIR_NAME" || exit 1

if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS specific configuration patches..."
    # The flag '-force_cpusubtype_ALL' is deprecated/removed in modern clang/Xcode
    # and causes build failures. We remove it safely using regex (not line numbers).
    
    if [ -f "configure" ]; then
        run_sed 's/-force_cpusubtype_ALL//g' configure
    fi
    
    if [ -f "configure.ac" ]; then
        run_sed 's/-force_cpusubtype_ALL//g' configure.ac
    fi
fi

# 5. Configure
echo "Configuring libvorbis..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --disable-docs / --disable-examples: Simplify build.
# Note: libvorbis relies on pkg-config to find libogg. 
#       Ensure PKG_CONFIG_PATH includes $TOOL_DIR/lib/pkgconfig (set in build_fix.sh).
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    $CROSS_HOST_FLAG \
    --disable-docs \
    --disable-examples

checkStatus $? "Configuration failed"

# 6. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 7. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "libvorbis Build Complete"