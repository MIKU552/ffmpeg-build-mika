#!/bin/bash

# ==============================================================================
# Build Script for OpenJPEG (JPEG 2000 Codec)
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

echoSection "Building OpenJPEG"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/openjpeg"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/openjpeg"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.0.tar.gz
TARBALL="openjpeg-$VERSION.tar.gz"
URL="https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="openjpeg-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring OpenJPEG..."

# CMake Options:
# - BUILD_SHARED_LIBS=OFF: Static build.
# - BUILD_CODEC=OFF: Don't build CLI tools (opj_compress/decompress).
# - OPENJPEG_INSTALL_LIB_DIR=lib: Force install to 'lib' (not lib64) to simplify path detection.
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_CODEC=OFF \
    -DBUILD_TESTING=OFF \
    -DBUILD_DOC=OFF \
    -DOPENJPEG_INSTALL_LIB_DIR=lib

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
cmake --build build -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
cmake --install build
checkStatus $? "Installation failed"

# 7. Post-Install Fix for Static Linking
# ------------------------------------------------------------------------------
# OpenJPEG needs -lm (math) and -lpthread (threading) for static linking.
# We modify the .pc file to ensure FFmpeg picks these up.

echoSection "Patching libopenjp2.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/libopenjp2.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    FLAGS_TO_ADD=""
    
    # Check for Math library
    if ! grep -q -- "-lm" "$PC_FILE"; then
        FLAGS_TO_ADD="$FLAGS_TO_ADD -lm"
    fi
    
    # Check for Pthread library
    if ! grep -q -- "-lpthread" "$PC_FILE"; then
        FLAGS_TO_ADD="$FLAGS_TO_ADD -lpthread"
    fi

    if [ -n "$FLAGS_TO_ADD" ]; then
        echo "Injecting flags:$FLAGS_TO_ADD"
        
        # Prefer injecting into Libs.private
        if grep -q "Libs.private:" "$PC_FILE"; then
            run_sed "s/Libs.private:/Libs.private:$FLAGS_TO_ADD/g" "$PC_FILE"
        else
            run_sed "s/Libs:/Libs:$FLAGS_TO_ADD/g" "$PC_FILE"
        fi
        checkStatus $? "Patching libopenjp2.pc failed"
    else
        echo "Flags (-lm -lpthread) already present."
    fi
else
    echo "Error: libopenjp2.pc not found. Static linking will likely fail."
    exit 1
fi

echoSection "OpenJPEG Build Complete"