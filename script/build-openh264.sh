#!/bin/bash

# ==============================================================================
# Build Script for OpenH264 (Cisco H.264 Codec)
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

echoSection "Building OpenH264"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/openh264"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/openh264"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/cisco/openh264/archive/v2.3.1.tar.gz
TARBALL="openh264-$VERSION.tar.gz"
URL="https://github.com/cisco/openh264/archive/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="openh264-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Environment Setup (Architecture Detection)
cd "$SRC_DIR_NAME" || exit 1

# Detect OS and ARCH for OpenH264 Makefile
SYS_OS=$(uname -s)
SYS_ARCH=$(uname -m)

MAKE_OS="linux"
MAKE_ARCH="x86_64"

if [ "$SYS_OS" = "Darwin" ]; then
    MAKE_OS="darwin"
fi

if [ "$SYS_ARCH" = "aarch64" ] || [ "$SYS_ARCH" = "arm64" ]; then
    MAKE_ARCH="arm64"
elif [ "$SYS_ARCH" = "x86_64" ]; then
    MAKE_ARCH="x86_64"
fi

echo "Detected OS: $MAKE_OS, ARCH: $MAKE_ARCH"

# 5. Build
echo "Compiling..."

# make arguments:
# OS/ARCH: Required by OpenH264 Makefile
# PREFIX: Install location
# libraries: Only build the lib, not the console apps
make -j "$CPUS" \
    OS="$MAKE_OS" \
    ARCH="$MAKE_ARCH" \
    PREFIX="$TOOL_DIR" \
    libraries

checkStatus $? "Build failed"

# 6. Install
echo "Installing..."

# install-static: Only install static libraries (.a) and headers
make install-static \
    OS="$MAKE_OS" \
    ARCH="$MAKE_ARCH" \
    PREFIX="$TOOL_DIR"

checkStatus $? "Installation failed"

echoSection "OpenH264 Build Complete"