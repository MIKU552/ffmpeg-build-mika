#!/bin/bash

# ==============================================================================
# Build Script for FDK-AAC (Fraunhofer FDK AAC Codec Library)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - High-quality AAC encoding support
#   - Static linking fix (auto-injects C++ standard library dependencies)
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

echoSection "Building FDK-AAC"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/fdk-aac"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/fdk-aac"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/mstorsjo/fdk-aac/archive/v2.0.2.tar.gz
TARBALL="fdk-aac-${VERSION}.tar.gz"
URL="https://github.com/mstorsjo/fdk-aac/archive/v${VERSION}.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="fdk-aac-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure & Build
cd "$SRC_DIR_NAME" || exit 1

echo "Running autoreconf..."
# -f: force, -i: install missing files, -v: verbose
autoreconf -fiv
checkStatus $? "Autoreconf failed"

echo "Configuring fdk-aac..."
# --enable-static / --disable-shared: Critical for single-binary FFmpeg distribution
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared \
    --with-pic

checkStatus $? "Configuration failed"

echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Compilation failed"

echo "Installing..."
make install
checkStatus $? "Installation failed"

# 5. Post-Install Fix for Static Linking
# ------------------------------------------------------------------------------
# FDK-AAC is a C++ library. When linking statically via pkg-config (used by FFmpeg),
# the linker needs to know it depends on the C++ standard library.
# We manually patch the generated .pc file to include these flags.

echoSection "Patching fdk-aac.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/fdk-aac.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    # Check if we need to add C++ libs
    if ! grep -q "c++" "$PC_FILE"; then
        if [ "$OS_NAME" = "Darwin" ]; then
            # macOS uses libc++
            echo "Injecting -lc++ -lm for macOS..."
            # Replace Libs.private or Libs line to append dependencies
            run_sed 's/Libs.private:/Libs.private: -lc++ -lm/g' "$PC_FILE"
        else
            # Linux usually uses libstdc++
            echo "Injecting -lstdc++ -lm for Linux..."
            run_sed 's/Libs.private:/Libs.private: -lstdc++ -lm/g' "$PC_FILE"
        fi
        
        # Fallback if Libs.private doesn't exist (older versions), append to Libs
        if ! grep -q "Libs.private" "$PC_FILE"; then
             if [ "$OS_NAME" = "Darwin" ]; then
                run_sed 's/Libs:/Libs: -lc++ -lm/g' "$PC_FILE"
             else
                run_sed 's/Libs:/Libs: -lstdc++ -lm/g' "$PC_FILE"
             fi
        fi
        
        checkStatus $? "Patching fdk-aac.pc failed"
    else
        echo "C++ libraries already present in .pc file."
    fi
else
    echo "Warning: fdk-aac.pc not found. FFmpeg configure might fail due to missing C++ symbols."
fi

echoSection "FDK-AAC Build Complete"