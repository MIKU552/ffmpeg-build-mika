#!/bin/bash

# ==============================================================================
# Build Script for Opus (High-Quality Audio Codec)
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

echoSection "Building Opus"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/opus"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/opus"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# Primary: Official Release (Has configure script)
# Fallback: GitLab Tag (Needs autogen.sh)
TARBALL="opus.tar.gz"
PRIMARY_URL="https://downloads.xiph.org/releases/opus/opus-$VERSION.tar.gz"
BACKUP_URL="https://gitlab.xiph.org/xiph/opus/-/archive/v$VERSION/opus-v$VERSION.tar.gz"

echo "Downloading source..."
if curl -L -f --retry 3 --connect-timeout 10 -o "$TARBALL" "$PRIMARY_URL"; then
    echo "Download successful from xiph.org."
else
    echo "Primary download failed. Trying backup mirror (GitLab)..."
    download "$BACKUP_URL" "$TARBALL"
fi

# Unpack
SRC_DIR_NAME="opus-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring Opus..."

# Check if we need to generate the build system
if [ ! -f "configure" ]; then
    echo "configure script not found. Running autogen.sh..."
    if [ -f "autogen.sh" ]; then
        ./autogen.sh
        checkStatus $? "Autogen failed"
    else
        echo "Error: Neither configure nor autogen.sh found."
        exit 1
    fi
fi

# Flags:
# --enable-static / --disable-shared: Static build.
# --with-pic: Position Independent Code (recommended for static libs).
# --disable-extra-programs: Don't build demos/tests.
# --disable-doc: Skip documentation.
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --with-pic \
    --disable-extra-programs \
    --disable-doc

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "Opus Build Complete"