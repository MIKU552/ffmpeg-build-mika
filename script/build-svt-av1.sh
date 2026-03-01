#!/bin/sh

# Copyright 2022 Martin Riedl
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
VERSION=$(cat "$SCRIPT_DIR/../version/svt-av1")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "svt-av1" # Use -p
cd "svt-av1/"
checkStatus $? "change directory failed"

# download source
SVT_TARBALL="SVT-AV1-$VERSION.tar.gz"
SVT_UNPACK_DIR="SVT-AV1-$VERSION"
# Consider adding proxy if needed: https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$VERSION/$SVT_TARBALL
download https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$VERSION/$SVT_TARBALL "$SVT_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$SVT_TARBALL"
checkStatus $? "unpack failed"
rm "$SVT_TARBALL" # Clean up

# prepare build
cd "$SVT_UNPACK_DIR/"
checkStatus $? "change directory failed"

# Create build directory
mkdir -p "build"
checkStatus $? "create build directory failed"
cd "build/"
checkStatus $? "change directory to build failed"

echo "Configuring SVT-AV1 (No PGO)..."

# Use CMake configuration (Standard Release with LTO, no PGO flags)
CMAKE_COMMON_FLAGS="-DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR \
      -DSVT_AV1_LTO=ON \
      -DSVT_AV1_PGO=OFF \
      -DBUILD_SHARED_LIBS=NO"

# shellcheck disable=SC2086
cmake ${CMAKE_COMMON_FLAGS} ..
checkStatus $? "Configuration failed"

# Build
echo "Running SVT-AV1 Build..."
make -j $CPUS
checkStatus $? "build failed"

# Final install
echo "Installing SVT-AV1..."
make install
checkStatus $? "installation failed"

cd ../.. # Back to SOURCE_DIR/svt-av1