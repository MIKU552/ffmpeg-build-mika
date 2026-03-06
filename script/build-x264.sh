#!/bin/bash

# ==============================================================================
# Build Script for x264 (H.264 Video Encoder)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
# ==============================================================================

# 1. Argument Processing
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

echoSection "Building x264"

# 2. Setup Build Directory
# The main script (run_build) cleans the target source_subdir before calling this.
# We create the directory to hold the source.
TARGET_SRC_DIR="$SOURCE_DIR/x264"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# Using the stable master branch tarball from VideoLAN
URL="https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.gz"
download "$URL" "x264.tar.gz"

# 4. Extract
# Use strip-components to avoid needing to know the exact internal folder name
tar -zxf "x264.tar.gz" --strip-components=1
checkStatus $? "Unpack failed"

# 5. Configure
echo "Configuring x264..."

CROSS_HOST_FLAG=""
if [ "$TARGET_OS" = "Windows" ]; then
    CROSS_HOST_FLAG="--host=x86_64-w64-mingw32"
fi
# --enable-pic: Critical for linking this static lib into FFmpeg's shared libs
# --disable-cli: We only need the library, not the executable
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    $CROSS_HOST_FLAG \
    --enable-pic \
    --disable-cli

checkStatus $? "Configuration failed"

# 6. Compile
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Compilation failed"

# 7. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "x264 Build Complete"