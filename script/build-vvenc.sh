#!/bin/bash

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
# Merged for Linux & macOS compatibility
# [Modified] PGO steps entirely removed for faster and stabler builds.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# load functions
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/vvenc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "vvenc" # Use -p
cd "vvenc/"
checkStatus $? "change directory failed"

# download source
VVENC_TARBALL="vvenc-$VERSION.tar.gz"
VVENC_UNPACK_DIR="vvenc-$VERSION"
download https://github.com/fraunhoferhhi/vvenc/archive/$VERSION.tar.gz "$VVENC_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$VVENC_TARBALL"
checkStatus $? "unpack failed"
rm "$VVENC_TARBALL" # Clean up

# enter unpacked directory
cd "$VVENC_UNPACK_DIR/"
checkStatus $? "change directory failed"


# --- Standard Build (No PGO) ---
echoSection "Build vvenc"

mkdir -p "build"
checkStatus $? "create build directory failed"
cd "build/"
checkStatus $? "change directory to build failed"

# Configure with CMake (Standard Release with LTO, no PGO flags)
cmake -S .. -B build/release-static -G 'Ninja' \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_INSTALL_PREFIX=$TOOL_DIR \
      -DCMAKE_BUILD_TYPE=Release
checkStatus $? "Configuration failed"

# Build optimized
cmake --build build/release-static -j $CPUS
checkStatus $? "Build failed"

# Install optimized
cmake --build build/release-static --target install
checkStatus $? "Installation failed"

cd ../.. # Back to SOURCE_DIR/vvenc