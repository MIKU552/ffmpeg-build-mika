#!/bin/bash

# ==============================================================================
# Build Script for AOM (Alliance for Open Media AV1 Codec)
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

echoSection "Building AOM (libaom)"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/aom"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found at $VERSION_FILE"
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/aom"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL format: https://storage.googleapis.com/aom-releases/libaom-3.6.1.tar.gz
TARBALL="libaom-$VERSION.tar.gz"
URL="https://storage.googleapis.com/aom-releases/libaom-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
tar -zxf "$TARBALL"
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
# Note: Source extracts to libaom-$VERSION
SOURCE_SUBDIR="libaom-$VERSION"
if [ ! -d "$SOURCE_SUBDIR" ]; then
    echo "Error: Expected source directory $SOURCE_SUBDIR not found."
    exit 1
fi

mkdir -p aom_build
cd aom_build || exit 1

echo "Configuring libaom..."

# Flags:
# - DENABLE_TESTS=0: Skip building tests to save time.
# - DENABLE_DOCS=0: Skip documentation.
# - DENABLE_EXAMPLES=0: Skip example binaries.
# - DENABLE_LTO=1: Enable Link Time Optimization (performance).
# - DBUILD_SHARED_LIBS=OFF: Build static library.
# - DENABLE_NASM=ON: Enable assembly optimizations (requires nasm).
cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
      -DENABLE_TESTS=0 \
      -DENABLE_DOCS=0 \
      -DENABLE_EXAMPLES=0 \
      -DENABLE_LTO=1 \
      -DBUILD_SHARED_LIBS=OFF \
      -DENABLE_NASM=ON \
      ../$SOURCE_SUBDIR

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."
make install
checkStatus $? "Installation failed"

echoSection "AOM Build Complete"