#!/bin/sh

# Copyright 2023 Martin Riedl
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
mkdir "libwebp"
checkStatus $? "create directory failed"
cd "libwebp/"
checkStatus $? "change directory failed"

# Get latest libwebp version from GitHub API
echo "Fetching latest libwebp version from GitHub..."
LATEST_LIBWEBP_TAG=$(curl -s https://api.github.com/repos/webmproject/libwebp/releases/latest | jq -r '.tag_name')
checkStatus $? "Failed to fetch latest libwebp tag"
echo "Latest libwebp tag: $LATEST_LIBWEBP_TAG"
# Version for directory name usually doesn't have 'v'
LATEST_LIBWEBP_VERSION_NO_V=$(echo "$LATEST_LIBWEBP_TAG" | sed 's/^v//')
checkStatus $? "Failed to parse libwebp version from tag"

# download source
# Tarball name from GitHub is usually just $TAG.tar.gz, but script uses libwebp.tar.gz
LIBWEBP_DOWNLOAD_URL="https://github.com/webmproject/libwebp/archive/refs/tags/${LATEST_LIBWEBP_TAG}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name_without_v_prefix>
LIBWEBP_UNPACK_DIR_ROOT="libwebp-${LATEST_LIBWEBP_VERSION_NO_V}"

download $LIBWEBP_DOWNLOAD_URL "libwebp.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "libwebp.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir libwebp_build
checkStatus $? "create build directory failed"
cd libwebp_build
checkStatus $? "change build directory failed"
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF ../$LIBWEBP_UNPACK_DIR_ROOT/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
