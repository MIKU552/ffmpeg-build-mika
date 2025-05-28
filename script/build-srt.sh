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
mkdir "srt"
checkStatus $? "create directory failed"
cd "srt/"
checkStatus $? "change directory failed"

# Get latest srt version from GitHub API
echo "Fetching latest srt version from GitHub..."
LATEST_SRT_TAG=$(get_latest_github_release_tag "Haivision/srt")
checkStatus $? "Failed to fetch latest srt tag from GitHub"
echo "Latest srt tag: $LATEST_SRT_TAG" # Should be like vX.Y.Z

LATEST_SRT_VERSION_NO_V=$(echo "$LATEST_SRT_TAG" | sed 's/^v//') # Remove 'v' prefix
checkStatus $? "Failed to parse srt version from tag (sed)"
echo "Latest srt version (no 'v'): $LATEST_SRT_VERSION_NO_V"

# download source
SRT_DOWNLOAD_URL="https://github.com/Haivision/srt/archive/refs/tags/${LATEST_SRT_TAG}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name_without_v_prefix>
SRT_UNPACK_DIR_ROOT="srt-${LATEST_SRT_VERSION_NO_V}"

download "$SRT_DOWNLOAD_URL" "srt.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "srt.tar.gz"
checkStatus $? "unpack failed"
# Note: The tarball unpacks to srt-${LATEST_SRT_VERSION_NO_V}
# The build will happen in a subdirectory.

# prepare build
mkdir srt_build
checkStatus $? "create build directory failed"
cd srt_build
checkStatus $? "change build directory failed"
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=OFF -DENABLE_APPS=OFF ../$SRT_UNPACK_DIR_ROOT/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
