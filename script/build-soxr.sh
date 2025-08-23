#!/bin/bash
# script/build-soxr.sh (Linux Fix)

# ---
# Functions
# ---
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
# shellcheck source=../script/functions.sh
. "$SCRIPT_DIR/functions.sh"

# ---
# Main
# ---

# Arguments
SCRIPT_DIR="$1"
SOURCE_DIR="$2"
TOOL_DIR="$3"
CPUS="$4"

# Get source code
SOXR_VERSION="0.1.3"
SOXR_URL="https://sourceforge.net/projects/soxr/files/soxr-${SOXR_VERSION}-Source.tar.xz/download"
SOXR_SOURCE_DIR="$SOURCE_DIR/soxr"

if [ ! -d "$SOXR_SOURCE_DIR" ]; then
    echo "Downloading SoXR source..."
    mkdir -p "$SOXR_SOURCE_DIR"
    curl -# -L "$SOXR_URL" | tar -xJ --strip-components=1 -C "$SOXR_SOURCE_DIR"
    checkStatus $? "Failed to download and extract SoXR"
else
    echo "SoXR source directory already exists."
fi


# Build and install
cd "$SOXR_SOURCE_DIR" || exit 1
rm -rf build
mkdir build && cd build

# Configure with CMake, explicitly setting library and pkgconfig paths
# This ensures files are installed into /lib and not /lib64, matching the main script's expectations.
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_INSTALL_LIBDIR="lib" \
    -DCMAKE_INSTALL_PKGCONFIGDIR="lib/pkgconfig" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_OPENMP=OFF \
    -DBUILD_TESTS=OFF

checkStatus $? "soxr cmake configure failed"

# Compile and install
make -j"$CPUS"
checkStatus $? "soxr make failed"

make install
checkStatus $? "soxr make install failed"