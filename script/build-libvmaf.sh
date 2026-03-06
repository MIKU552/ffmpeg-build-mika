#!/bin/bash

# ==============================================================================
# Build Script for libvmaf (Video Quality Assessment)
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

echoSection "Building libvmaf"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/libvmaf"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)
echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/libvmaf"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/Netflix/vmaf/archive/refs/tags/v2.3.1.tar.gz
TARBALL="libvmaf-$VERSION.tar.gz"
URL="https://github.com/Netflix/vmaf/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="libvmaf-src"
mkdir -p "$SRC_DIR_NAME"
# Extract to standard directory
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Environment Setup (Meson)
prepareMeson

# 5. Configure
# Critical: The C library build logic is inside the 'libvmaf' subdirectory
cd "$SRC_DIR_NAME/libvmaf" || exit 1

echo "Configuring libvmaf..."
MESON_CROSS_FLAGS=""
if [ "$TARGET_OS" = "Windows" ]; then
    # 强制指定交叉编译文件
    MESON_CROSS_FLAGS="--cross-file $SCRIPT_DIR/mingw64-meson.txt"
fi
# Options:
# --libdir=lib: Force install to 'lib' directory.
# --default-library=static: Static linking requirement.
# -Dbuilt_in_models=true: Embed models into the binary (makes ffmpeg portable!).
# -Db_lto=true: Enable Link Time Optimization.
meson setup build \
    --prefix="$TOOL_DIR" \
    --libdir=lib \
    --default-library=static \
    $MESON_CROSS_FLAGS \
    --buildtype=release \
    -Dbuilt_in_models=true \
    -Db_lto=true \
    -Denable_float=true

checkStatus $? "Configuration failed"

# 6. Build
echo "Compiling..."
ninja -C build -j "$CPUS"
checkStatus $? "Build failed"

# 7. Install
echo "Installing..."
ninja -C build install
checkStatus $? "Installation failed"

# 8. Post-Install Fix for Static Linking
# ------------------------------------------------------------------------------
# libvmaf is C++, but exposes C API. Static linking often fails because
# the .pc file doesn't explicitly link against the C++ standard library.

echoSection "Patching libvmaf.pc"
PC_FILE="$TOOL_DIR/lib/pkgconfig/libvmaf.pc"

if [ -f "$PC_FILE" ]; then
    echo "Found pkg-config file: $PC_FILE"
    
    # Check OS to decide which C++ lib to inject
    CPP_LIB="-lstdc++"
    if [ "$OS_NAME" = "Darwin" ]; then
        CPP_LIB="-lc++"
    fi

    # Check if already present
    if ! grep -q -- "$CPP_LIB" "$PC_FILE"; then
        echo "Injecting $CPP_LIB into libvmaf.pc..."
        # Replace '-lvmaf' with '-lvmaf -lstdc++' (or -lc++)
        run_sed "s/-lvmaf/-lvmaf $CPP_LIB/g" "$PC_FILE"
        checkStatus $? "Patching libvmaf.pc failed"
    else
        echo "C++ library already linked in .pc file."
    fi
else
    echo "Warning: libvmaf.pc not found. Static linking might fail."
fi

echoSection "libvmaf Build Complete"