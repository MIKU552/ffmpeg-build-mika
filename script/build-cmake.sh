#!/bin/bash

# ==============================================================================
# Build Script for CMake
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - Preferentially downloads official pre-compiled binaries (fast)
#   - Falls back to source compilation if binaries are unavailable
#   - Cross-platform support (Linux x86_64/aarch64, macOS Universal)
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

echoSection "Installing CMake"

# 2. Version Setup
# Try to read version from file, otherwise default to 3.30.5
VERSION_FILE="$SCRIPT_DIR/../version/cmake"
if [ -f "$VERSION_FILE" ]; then
    VERSION_PATCH=$(cat "$VERSION_FILE")
else
    VERSION_PATCH="3.30.5"
fi
# Extract Major.Minor for source URL (e.g., 3.30.5 -> 3.30)
VERSION_MINOR=$(echo "$VERSION_PATCH" | cut -d. -f1-2)

echo "Target Version: $VERSION_PATCH"

# 3. Check Existing Installation
# We check if the 'cmake' in path matches our target version.
if command -v cmake >/dev/null 2>&1; then
    CURRENT_VERSION=$(cmake --version | head -n 1 | awk '{print $3}')
    echo "Detected installed CMake version: $CURRENT_VERSION"
    
    if [ "$CURRENT_VERSION" = "$VERSION_PATCH" ]; then
        echo "CMake $VERSION_PATCH is already installed. Skipping."
        exit 0
    fi
fi

# Prepare Workspace
TARGET_SRC_DIR="$SOURCE_DIR/cmake"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 4. Attempt Binary Download (Fast Path)
# ------------------------------------------------------------------------------
echoSection "Attempting Binary Download"

OS_NAME=$(uname -s)
ARCH_NAME=$(uname -m)
CMAKE_OS=""
CMAKE_ARCH=""
IS_BINARY_AVAILABLE="NO"

if [ "$OS_NAME" = "Darwin" ]; then
    CMAKE_OS="macos"
    CMAKE_ARCH="universal"
    IS_BINARY_AVAILABLE="YES"
elif [ "$OS_NAME" = "Linux" ]; then
    CMAKE_OS="linux"
    if [ "$ARCH_NAME" = "x86_64" ]; then
        CMAKE_ARCH="x86_64"
        IS_BINARY_AVAILABLE="YES"
    elif [ "$ARCH_NAME" = "aarch64" ]; then
        CMAKE_ARCH="aarch64"
        IS_BINARY_AVAILABLE="YES"
    fi
fi

if [ "$IS_BINARY_AVAILABLE" = "YES" ]; then
    BINARY_TAR="cmake-${VERSION_PATCH}-${CMAKE_OS}-${CMAKE_ARCH}.tar.gz"
    BINARY_URL="https://github.com/Kitware/CMake/releases/download/v${VERSION_PATCH}/${BINARY_TAR}"
    
    echo "Downloading binary from: $BINARY_URL"
    # Use curl explicitly here to handle the check easier
    if curl -L -f --retry 3 --connect-timeout 10 -o "$BINARY_TAR" "$BINARY_URL"; then
        echo "Binary download successful. Installing..."
        
        # Unpack
        tar -zxf "$BINARY_TAR"
        checkStatus $? "Unpack failed"
        
        # Determine extraction root
        EXTRACT_DIR="cmake-${VERSION_PATCH}-${CMAKE_OS}-${CMAKE_ARCH}"
        
        # macOS binaries are inside a CMake.app bundle
        if [ "$OS_NAME" = "Darwin" ]; then
            cd "$EXTRACT_DIR/CMake.app/Contents" || exit 1
        else
            cd "$EXTRACT_DIR" || exit 1
        fi
        
        # Install to TOOL_DIR
        echo "Copying binaries to $TOOL_DIR..."
        mkdir -p "$TOOL_DIR/bin" "$TOOL_DIR/share"
        cp -R bin/* "$TOOL_DIR/bin/"
        cp -R share/* "$TOOL_DIR/share/"
        
        # On macOS/Linux, sometimes 'man' or 'doc' folders exist, copy if needed
        if [ -d "man" ]; then mkdir -p "$TOOL_DIR/man"; cp -R man/* "$TOOL_DIR/man/"; fi
        
        echo "CMake binary installed successfully."
        exit 0
    else
        echo "Binary download failed or not found. Falling back to source build."
        rm -f "$BINARY_TAR"
    fi
else
    echo "No pre-compiled binary for $OS_NAME $ARCH_NAME. Falling back to source build."
fi

# 5. Source Build (Fallback)
# ------------------------------------------------------------------------------
echoSection "Building CMake from Source"

SOURCE_TAR="cmake-$VERSION_PATCH.tar.gz"
SOURCE_URL="https://cmake.org/files/v$VERSION_MINOR/$SOURCE_TAR"

download "$SOURCE_URL" "$SOURCE_TAR"

# Clean previous build attempt
rm -rf "cmake-$VERSION_PATCH"
tar -zxf "$SOURCE_TAR"
checkStatus $? "Source unpack failed"
rm "$SOURCE_TAR"

cd "cmake-$VERSION_PATCH" || exit 1

echo "Configuring CMake..."
# Ensure OpenSSL is found if we built it
export OPENSSL_ROOT_DIR="$TOOL_DIR"

./configure \
    --prefix="$TOOL_DIR" \
    --parallel="$CPUS"

checkStatus $? "Configuration failed"

echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "CMake Build Complete"