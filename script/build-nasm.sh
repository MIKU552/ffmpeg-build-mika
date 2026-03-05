#!/bin/bash

# ==============================================================================
# Build Script for NASM (Netwide Assembler)
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

echoSection "Building NASM"

# 2. Architecture Check
# NASM is x86 assembly. It is useless on ARM (Apple Silicon, etc.)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    echo "Architecture is $ARCH. NASM is not required. Skipping."
    exit 0
fi

# 3. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/nasm"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/nasm"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 4. Download Source
# Try official site first, fallback to GitHub
TARBALL="nasm-${VERSION}.tar.gz"
PRIMARY_URL="https://www.nasm.us/pub/nasm/releasebuilds/${VERSION}/nasm-${VERSION}.tar.gz"
# Note: GitHub release tags often format as 'nasm-X.XX.XX'
GITHUB_URL="https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${VERSION}.tar.gz"

echo "Downloading source..."
if curl -L -f --retry 3 --connect-timeout 10 -o "$TARBALL" "$PRIMARY_URL"; then
    echo "Download successful from nasm.us."
else
    echo "Primary download failed. Trying backup mirror (GitHub)..."
    download "$GITHUB_URL" "$TARBALL"
fi

# Unpack
SRC_DIR_NAME="nasm-src"
mkdir -p "$SRC_DIR_NAME"
# Use strip-components to handle arbitrary internal folder names
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 5. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring NASM..."

# If downloading from GitHub, 'configure' might be missing
if [ ! -f "configure" ]; then
    echo "configure script not found. Running autogen.sh..."
    ./autogen.sh
    checkStatus $? "Autogen failed"
fi

./configure \
    --prefix="$TOOL_DIR" \
    --enable-sections

checkStatus $? "Configuration failed"

# 6. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 7. Install
echo "Installing..."

# Trick: Create dummy man pages to prevent make install from failing
# if asciidoc/xmlto are missing.
touch nasm.1 ndisasm.1

make install
checkStatus $? "Installation failed"

echoSection "NASM Build Complete"