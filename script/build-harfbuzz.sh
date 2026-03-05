#!/bin/bash

# ==============================================================================
# Build Script for HarfBuzz (Text Shaping Engine)
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

echoSection "Building HarfBuzz"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/harfbuzz"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/harfbuzz"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/harfbuzz/harfbuzz/releases/download/8.2.1/harfbuzz-8.2.1.tar.xz
TARBALL="harfbuzz-$VERSION.tar.xz"
URL="https://github.com/harfbuzz/harfbuzz/releases/download/$VERSION/harfbuzz-$VERSION.tar.xz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="harfbuzz-src"
mkdir -p "$SRC_DIR_NAME"
tar -xf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Environment Setup (Meson)
prepareMeson

# 5. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring HarfBuzz..."

# Options:
# --libdir=lib: Force install to 'lib' directory.
# --default-library=static: Static linking requirement.
# -Dglib=disabled: Disable GLib dependency (keeps build lightweight, usually not needed for subtitles).
# -Dfreetype=enabled: Enable FreeType integration (Crucial for libass).
# -Ddocs=disabled: Skip documentation.
# -Db_lto=true: Enable Link Time Optimization.
meson setup build \
    --prefix="$TOOL_DIR" \
    --libdir=lib \
    --default-library=static \
    -Dbuildtype=release \
    -Dglib=disabled \
    -Dfreetype=enabled \
    -Ddocs=disabled \
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

echoSection "HarfBuzz Build Complete"