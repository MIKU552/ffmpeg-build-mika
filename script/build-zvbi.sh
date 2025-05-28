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

CFLAGS="-D_GNU_SOURCE $CFLAGS"
export CFLAGS

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
mkdir "zvbi"
checkStatus $? "create directory failed"
cd "zvbi/"
checkStatus $? "change directory failed"

# Get latest zvbi version from GitHub API (libzvbi/zvbi)
echo "Fetching latest zvbi version from GitHub (libzvbi/zvbi)..."
LATEST_ZVBI_TAG=$(get_latest_github_release_tag "libzvbi/zvbi")
checkStatus $? "Failed to fetch latest zvbi tag from GitHub"
echo "Latest zvbi tag: $LATEST_ZVBI_TAG" # Should be like vX.Y.Z

LATEST_ZVBI_VERSION=$(echo "$LATEST_ZVBI_TAG" | sed 's/^v//') # Remove 'v' prefix
checkStatus $? "Failed to parse zvbi version from tag (sed)"
echo "Latest zvbi version: $LATEST_ZVBI_VERSION"

# download source
ZVBI_DOWNLOAD_URL="https://github.com/libzvbi/zvbi/archive/refs/tags/${LATEST_ZVBI_TAG}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name_without_v_prefix>
ZVBI_UNPACK_DIR="zvbi-${LATEST_ZVBI_VERSION}"

download "$ZVBI_DOWNLOAD_URL" "zvbi.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "zvbi.tar.gz"
checkStatus $? "unpack failed"
cd "$ZVBI_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
echoSection "configure zvbi $LATEST_ZVBI_VERSION"
chmod +x autogen.sh
./autogen.sh && ./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
