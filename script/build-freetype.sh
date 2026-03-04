#!/bin/bash

# ==============================================================================
# Build Script for FreeType (Font Rendering Engine)
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

echoSection "Building FreeType"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/freetype"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/freetype"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# Try GNU Savannah first, fallback to SourceForge
TARBALL="freetype-${VERSION}.tar.gz"
PRIMARY_URL="https://download.savannah.gnu.org/releases/freetype/freetype-${VERSION}.tar.gz"
MIRROR_URL="https://sourceforge.net/projects/freetype/files/freetype2/${VERSION}/freetype-${VERSION}.tar.gz/download"

echo "Downloading source..."
if curl -L -f --retry 3 --connect-timeout 10 -o "$TARBALL" "$PRIMARY_URL"; then
    echo "Download successful from primary mirror."
else
    echo "Primary download failed. Trying backup mirror (SourceForge)..."
    download "$MIRROR_URL" "$TARBALL"
fi

# Unpack
SRC_DIR_NAME="freetype-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring FreeType..."

# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --without-harfbuzz: Break circular dependency (HarfBuzz depends on FreeType).
# --without-png: Disable PNG support to avoid linking against system libpng (portability).
# --with-zlib=yes: Use the zlib we built (found via pkg-config/tool-dir).
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --with-zlib=yes \
    --without-harfbuzz \
    --without-png \
    --without-bzip2

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "FreeType Build Complete"