#!/bin/sh

# Copyright 2021 Martin Riedl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4
# Reconstruct LOG_DIR path
LOG_DIR="$(pwd)/log"

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "ninja" # Use -p
cd "ninja/"
checkStatus $? "change directory failed"

# download source
if [ -d "ninja" ]; then
    # source code already exists
    echo "skip download"
else
    # download now
    echo "Fetching latest ninja version from GitHub..."
    LATEST_NINJA_TAG=$(curl -s https://api.github.com/repos/ninja-build/ninja/releases/latest | jq -r '.tag_name')
    checkStatus $? "Failed to fetch latest ninja tag"
    echo "Latest ninja tag: $LATEST_NINJA_TAG" # Should be like vX.Y.Z

    download https://github.com/ninja-build/ninja/archive/refs/tags/${LATEST_NINJA_TAG}.tar.gz "ninja.tar.gz"
    checkStatus $? "download failed"

    # unpack
    tar -zxf "ninja.tar.gz"
    checkStatus $? "unpack failed"
    # Assume tarball unpacks to 'ninja-1.11.1' or similar based on version
    # Find the unpacked directory name (adjust pattern if needed)
    UNPACKED_DIR=$(find . -maxdepth 1 -type d -name 'ninja-*' | head -n 1)
    if [ -z "$UNPACKED_DIR" ]; then
        echo "ERROR: Could not find unpacked ninja directory."
        exit 1
    fi
    mv "$UNPACKED_DIR" ninja # Rename to predictable 'ninja'
    checkStatus $? "rename failed"
fi
cd "ninja/"
checkStatus $? "change directory failed"

# prepare build
mkdir -p ninja_build
checkStatus $? "create directory failed"
cd ninja_build/
checkStatus $? "change directory failed"

# --- FIX: Force include cstdint for googletest compilation ---
echo "Exporting CXXFLAGS to include cstdint for googletest..."
# Preserve existing CXXFLAGS set by build.sh (which includes -fPIC)
ORIGINAL_CXXFLAGS="${CXXFLAGS}"
export CXXFLAGS="-include cstdint ${ORIGINAL_CXXFLAGS}"
echo "DEBUG: CXXFLAGS for ninja build: ${CXXFLAGS}"
# --- End FIX ---

# Run CMake - it should pick up the CXXFLAGS
cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" -DBUILD_TESTING=OFF ..
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# Restore CXXFLAGS? Not strictly needed as script likely runs in subshell env.
# export CXXFLAGS="${ORIGINAL_CXXFLAGS}"

# Go back to the directory build-ninja.sh was called from ($SOURCE_DIR/ninja)
cd .. # Back to 'ninja' dir
checkStatus $? "Failed cd back to ninja dir"
cd .. # Back to 'ninja' parent dir ($SOURCE_DIR/ninja)
checkStatus $? "Failed cd back to SOURCE_DIR/ninja"

# Note: Success marker logic was removed previously
# If needed: touch "$LOG_DIR/build-ninja.success"