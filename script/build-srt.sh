#!/bin/bash

# ==============================================================================
# Build Script for SRT (Secure Reliable Transport)
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

echoSection "Building SRT"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/srt"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/srt"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/Haivision/srt/archive/refs/tags/v1.5.3.tar.gz
TARBALL="srt-$VERSION.tar.gz"
URL="https://github.com/Haivision/srt/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="srt-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring SRT..."
CMAKE_CROSS_FLAGS=""
if [ "$TARGET_OS" = "Windows" ]; then
    CMAKE_CROSS_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SCRIPT_DIR/mingw64.cmake"
fi
# CMake Options:
# - CMAKE_INSTALL_LIBDIR=lib: Force install to 'lib' (not lib64).
# - ENABLE_SHARED=OFF: Static build.
# - ENABLE_APPS=OFF: Don't build tools (srt-live-transmit, etc).
# - OPENSSL_ROOT_DIR: Critical! Point to our custom static OpenSSL build.
# - OPENSSL_USE_STATIC_LIBS=ON: Ensure we link against static libssl/libcrypto.
# - ENABLE_HEAVY_LOGGING=OFF: Optimize for performance/size.
cmake -S . -B build -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_SHARED=OFF \
    -DENABLE_STATIC=ON \
    $CMAKE_CROSS_FLAGS \
    -DENABLE_APPS=OFF \
    -DENABLE_HEAVY_LOGGING=OFF \
    -DOPENSSL_ROOT_DIR="$TOOL_DIR" \
    -DOPENSSL_USE_STATIC_LIBS=ON

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
# SRT's pkg-config file (srt.pc) sometimes misses the dependency on OpenSSL
# and Pthread when linking statically.

echoSection "Patching srt.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/srt.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    # We need to ensure -lssl -lcrypto -lpthread are in Libs.private (or Libs)
    # Since we built OpenSSL statically, these are mandatory.
    
    FLAGS_TO_ADD=""
    if ! grep -q -- "-lssl" "$PC_FILE"; then FLAGS_TO_ADD="$FLAGS_TO_ADD -lssl"; fi
    if ! grep -q -- "-lcrypto" "$PC_FILE"; then FLAGS_TO_ADD="$FLAGS_TO_ADD -lcrypto"; fi
    if ! grep -q -- "-lpthread" "$PC_FILE"; then FLAGS_TO_ADD="$FLAGS_TO_ADD -lpthread"; fi

    if [ -n "$FLAGS_TO_ADD" ]; then
        echo "Injecting flags:$FLAGS_TO_ADD"
        if grep -q "Libs.private:" "$PC_FILE"; then
            run_sed "s/Libs.private:/Libs.private:$FLAGS_TO_ADD/g" "$PC_FILE"
        else
            # Some versions of SRT pc file might not have Libs.private
            run_sed "s/Libs:/Libs:$FLAGS_TO_ADD/g" "$PC_FILE"
        fi
        checkStatus $? "Patching srt.pc failed"
    else
        echo "Dependencies seem correct."
    fi
else
    echo "Warning: srt.pc not found."
fi

echoSection "SRT Build Complete"