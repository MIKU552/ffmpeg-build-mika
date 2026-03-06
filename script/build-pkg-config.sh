#!/bin/bash

# ==============================================================================
# Build Script for pkg-config (Library Helper)
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

echoSection "Building pkg-config"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/pkg-config"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)
echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/pkg-config"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
TARBALL="pkg-config-$VERSION.tar.gz"
URL="https://pkg-config.freedesktop.org/releases/pkg-config-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="pkg-config-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring pkg-config..."
if [ "$TARGET_OS" = "Windows" ]; then
    echo "Reverting to native Linux compiler for NASM host tool..."
    unset CC CXX AR AS LD RANLIB STRIP NM WINDRES PKG_CONFIG_LIBDIR
fi
# Compiler Flags:
# The internal GLib used by pkg-config is old and triggers errors on modern Clang/GCC.
# Specifically, strict integer conversion checks on macOS need to be relaxed.
EXTRA_CFLAGS=""
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS compatibility flags..."
    EXTRA_CFLAGS="-Wno-int-conversion"
fi

# Search Paths:
# We strictly define where pkg-config should look for .pc files.
# By default, we only want it to look in our TOOL_DIR.
DEFAULT_SEARCH_PATH="$TOOL_DIR/lib/pkgconfig"
if [ "$OS_NAME" = "Linux" ]; then
    # Some libs on Linux might end up in lib64, though we try to avoid it.
    DEFAULT_SEARCH_PATH="$DEFAULT_SEARCH_PATH:$TOOL_DIR/lib64/pkgconfig"
fi

# Configure:
# --with-internal-glib: Use bundled GLib (avoids circular dependency).
# --disable-host-tool: Don't prefix the tool name.
# --with-pc-path: Set the default search path.
./configure \
    --prefix="$TOOL_DIR" \
    --with-internal-glib \
    --disable-host-tool \
    --disable-shared \
    --with-pc-path="$DEFAULT_SEARCH_PATH" \
    CFLAGS="$CFLAGS $EXTRA_CFLAGS"

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "pkg-config Build Complete"