#!/bin/sh

# Copyright 2022 Martin Riedl
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

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "harfbuzz"
checkStatus $? "create directory failed"
cd "harfbuzz/"
checkStatus $? "change directory failed"

# Get latest harfbuzz version from GitHub API
echo "Fetching latest harfbuzz version from GitHub..."
LATEST_HARFBUZZ_VERSION=$(curl -s https://api.github.com/repos/harfbuzz/harfbuzz/releases/latest | jq -r '.tag_name')
checkStatus $? "Failed to fetch latest harfbuzz version"
echo "Latest harfbuzz version: $LATEST_HARFBUZZ_VERSION"

# download source
HARFBUZZ_TARBALL="harfbuzz-$LATEST_HARFBUZZ_VERSION.tar.xz"
HARFBUZZ_UNPACK_DIR="harfbuzz-$LATEST_HARFBUZZ_VERSION"
download https://github.com/harfbuzz/harfbuzz/releases/download/$LATEST_HARFBUZZ_VERSION/$HARFBUZZ_TARBALL "$HARFBUZZ_TARBALL"
checkStatus $? "download failed"

# unpack
tar -xf "$HARFBUZZ_TARBALL"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "$HARFBUZZ_UNPACK_DIR/"
checkStatus $? "change directory failed"
meson build --prefix "$TOOL_DIR" --libdir=lib --default-library=static
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"
