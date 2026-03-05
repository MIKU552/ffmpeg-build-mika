#!/bin/bash

# ==============================================================================
# Build Script for Ninja (Small Build System with a focus on speed)
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

echoSection "Installing Ninja"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/ninja"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/ninja"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Attempt Binary Download (Fast Path)
# ------------------------------------------------------------------------------
# Ninja releases usually contain static binaries. We try to use them first.

OS_NAME=$(uname -s)
ARCH_NAME=$(uname -m)
BINARY_URL=""
BINARY_ZIP=""

if [ "$OS_NAME" = "Darwin" ]; then
    BINARY_ZIP="ninja-mac.zip"
    BINARY_URL="https://github.com/ninja-build/ninja/releases/download/v${VERSION}/ninja-mac.zip"
elif [ "$OS_NAME" = "Linux" ]; then
    if [ "$ARCH_NAME" = "x86_64" ]; then
        BINARY_ZIP="ninja-linux.zip"
        BINARY_URL="https://github.com/ninja-build/ninja/releases/download/v${VERSION}/ninja-linux.zip"
    elif [ "$ARCH_NAME" = "aarch64" ]; then
        BINARY_ZIP="ninja-linux-aarch64.zip"
        BINARY_URL="https://github.com/ninja-build/ninja/releases/download/v${VERSION}/ninja-linux-aarch64.zip"
    fi
fi

# Try to download binary if URL is determined
if [ -n "$BINARY_URL" ]; then
    echo "Attempting to download binary from: $BINARY_URL"
    if curl -L -f --retry 3 --connect-timeout 10 -o "$BINARY_ZIP" "$BINARY_URL"; then
        echo "Binary download successful. Installing..."
        
        # Need unzip for ninja releases
        if command -v unzip >/dev/null 2>&1; then
            unzip -o "$BINARY_ZIP"
            checkStatus $? "Unzip failed"
            
            # Install
            mkdir -p "$TOOL_DIR/bin"
            chmod +x ninja
            cp ninja "$TOOL_DIR/bin/"
            checkStatus $? "Copy binary failed"
            
            echo "Ninja binary installed successfully."
            exit 0
        else
            echo "Warning: 'unzip' command not found. Falling back to source build."
        fi
    else
        echo "Binary download failed or not found. Falling back to source build."
    fi
fi

# 4. Source Build (Fallback)
# ------------------------------------------------------------------------------
echoSection "Building Ninja from Source"

TARBALL="ninja-$VERSION.tar.gz"
SOURCE_URL="https://github.com/ninja-build/ninja/archive/refs/tags/v$VERSION.tar.gz"

download "$SOURCE_URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="ninja-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

cd "$SRC_DIR_NAME" || exit 1

echo "Configuring Ninja..."

# Flags:
# -DBUILD_TESTING=OFF: Disable tests (removes GoogleTest dependency and cstdint issues).
# -DCMAKE_CXX_FLAGS="-include cstdint": Explicitly fix GCC 13+ issue if tests are enabled or if source code needs it.
cmake -S . -B build \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_FLAGS="-include cstdint"

checkStatus $? "Configuration failed"

# Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

echoSection "Ninja Build Complete"