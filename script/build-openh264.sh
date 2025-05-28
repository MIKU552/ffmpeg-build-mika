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

# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openh264"
checkStatus $? "create directory failed"
cd "openh264/"
checkStatus $? "change directory failed"

# Get latest openh264 version from GitHub API
echo "Fetching latest openh264 version from GitHub..."
LATEST_OPENH264_TAG=$(get_latest_github_release_tag "cisco/openh264")
checkStatus $? "Failed to fetch latest openh264 tag from GitHub"
echo "Latest openh264 tag: $LATEST_OPENH264_TAG" # Should be like vX.Y.Z

LATEST_OPENH264_VERSION_NO_V=$(echo "$LATEST_OPENH264_TAG" | sed 's/^v//') # Remove 'v' prefix
checkStatus $? "Failed to parse openh264 version from tag (sed)"
echo "Latest openh264 version (no 'v'): $LATEST_OPENH264_VERSION_NO_V"

# download source
OPENH264_DOWNLOAD_URL="https://github.com/cisco/openh264/archive/refs/tags/${LATEST_OPENH264_TAG}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name_without_v_prefix>
OPENH264_UNPACK_DIR="openh264-${LATEST_OPENH264_VERSION_NO_V}"

download "$OPENH264_DOWNLOAD_URL" "openh264.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "openh264.tar.gz"
checkStatus $? "unpack failed"
cd "$OPENH264_UNPACK_DIR/"
checkStatus $? "change directory failed"

# build
make PREFIX="$TOOL_DIR" -j $CPUS
checkStatus $? "build failed"

# install
make install-static PREFIX="$TOOL_DIR"
checkStatus $? "installation failed"
