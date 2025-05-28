#!/bin/sh

# Copyright 2021 Martin Riedl
# Merged for Linux & macOS compatibility

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

# load functions
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "nasm" # Use -p
cd "nasm/"
checkStatus $? "change directory failed"

# Get latest nasm version from nasm.us
echo "Fetching latest nasm version from nasm.us..."
# This command looks for directory links like <a href="2.16.01/">, extracts "2.16.01", sorts, and takes the latest.
LATEST_NASM_VERSION=$(curl -sL https://www.nasm.us/pub/nasm/releasebuilds/ | \
    grep -oP 'href="([0-9\.]+)/"' | \
    sed -E 's|href="([0-9\.]+)/"|\1|' | \
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)*$' | \
    sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest nasm version"
echo "Latest nasm version: $LATEST_NASM_VERSION"

# download source
NASM_SUBDIR="nasm-src" # Use a subdirectory
mkdir -p "$NASM_SUBDIR"
checkStatus $? "create directory failed"
NASM_PRIMARY_URL="http://www.nasm.us/pub/nasm/releasebuilds/$LATEST_NASM_VERSION/nasm-$LATEST_NASM_VERSION.tar.gz"
NASM_GITHUB_TAG="nasm-$LATEST_NASM_VERSION" # Construct GitHub tag based on fetched version
NASM_GITHUB_URL="https://github.com/netwide-assembler/nasm/archive/refs/tags/$NASM_GITHUB_TAG.tar.gz"

download $NASM_PRIMARY_URL nasm.tar.gz
if [ $? -ne 0 ]; then
    echo "Download from nasm.us failed; trying GitHub mirror"
    download $NASM_GITHUB_URL nasm.tar.gz
    checkStatus $? "Download from GitHub mirror failed"
fi

# unpack
tar -zxf "nasm.tar.gz" -C "$NASM_SUBDIR" --strip-components=1
checkStatus $? "unpack failed"
rm nasm.tar.gz # Clean up tarball
cd "$NASM_SUBDIR/"
checkStatus $? "change directory failed"

# prepare build
if [ -f "configure" ]; then
    echo "configure file found; continue"
else
    echo "run autogen first"
    ./autogen.sh
    checkStatus $? "autogen failed" # Check status
fi
./configure --prefix="$TOOL_DIR"
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

touch ./nasm.1
touch ./ndisasm.1

# install
make install
checkStatus $? "installation failed"