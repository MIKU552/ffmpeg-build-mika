#!/bin/bash

# ==============================================================================
# Build Script for zimg (Scaling, Colorspace Conversion, Dithering Library)
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

echoSection "Building zimg"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/zimg"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)
echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/zimg"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.5.tar.gz
TARBALL="zimg-$VERSION.tar.gz"
URL="https://github.com/sekrit-twc/zimg/archive/refs/tags/release-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="zimg-src"
mkdir -p "$SRC_DIR_NAME"
# Use strip-components to ignore the "zimg-release-X.X.X" directory name
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Generating build system..."
./autogen.sh
checkStatus $? "Autogen failed"

echo "Configuring zimg..."
CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# Flags:
# --enable-static / --disable-shared: Static linking requirement.
# --libdir: Force install to 'lib' to avoid 'lib64' confusion on some distros.
./configure \
    --prefix="$TOOL_DIR" \
    --libdir="$TOOL_DIR/lib" \
    --enable-static \
    $CROSS_HOST_FLAG \
    --disable-shared

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

# 7. Post-Install Fix for Static Linking
# ------------------------------------------------------------------------------
# zimg is C++, but exposes C API.
# 1. It often needs explicit linking to libm (-lm).
# 2. Static linking often fails because the .pc file misses -lstdc++ (or -lc++).

echoSection "Patching zimg.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/zimg.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    # --- Fix 1: Add -lm (Math Library) ---
    if ! grep -q -- "-lm" "$PC_FILE"; then
        echo "Injecting -lm..."
        # Try appending to Libs.private first, then Libs
        if grep -q "Libs.private:" "$PC_FILE"; then
            run_sed 's/Libs.private:/Libs.private: -lm/g' "$PC_FILE"
        else
            run_sed 's/Libs:/Libs: -lm/g' "$PC_FILE"
        fi
    fi

    # --- Fix 2: Add C++ Standard Library ---
    CPP_LIB="-lstdc++"
    if [ "$OS_NAME" = "Darwin" ]; then
        CPP_LIB="-lc++"
    fi

    if ! grep -q -- "$CPP_LIB" "$PC_FILE"; then
        echo "Injecting $CPP_LIB..."
        if grep -q "Libs.private:" "$PC_FILE"; then
            run_sed "s/Libs.private:/Libs.private: $CPP_LIB/g" "$PC_FILE"
        else
            run_sed "s/Libs:/Libs: $CPP_LIB/g" "$PC_FILE"
        fi
    fi
    
    checkStatus $? "Patching zimg.pc failed"
else
    echo "Warning: zimg.pc not found. Static linking might fail."
fi

echoSection "zimg Build Complete"