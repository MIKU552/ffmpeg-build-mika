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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/nasm")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "nasm" # Use -p
cd "nasm/"
checkStatus $? "change directory failed"

# download source
NASM_SUBDIR="nasm-src" # Use a subdirectory
mkdir -p "$NASM_SUBDIR"
checkStatus $? "create directory failed"
download http://www.nasm.us/pub/nasm/releasebuilds/$VERSION/nasm-$VERSION.tar.gz nasm.tar.gz
if [ $? -ne 0 ]; then
    echo "download failed; start download from github server"
    # Use gh-proxy if needed
    # download https://gh-proxy.com/https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-$VERSION.tar.gz nasm.tar.gz
    download https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-$VERSION.tar.gz nasm.tar.gz
    checkStatus $? "download failed"
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