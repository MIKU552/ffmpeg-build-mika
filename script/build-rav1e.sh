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
mkdir "rav1e"
checkStatus $? "create directory failed"
cd "rav1e/"
checkStatus $? "change directory failed"

# Get latest rav1e version from GitHub API
echo "Fetching latest rav1e version from GitHub..."
LATEST_RAV1E_TAG=$(get_latest_github_release_tag "xiph/rav1e")
checkStatus $? "Failed to fetch latest rav1e tag from GitHub"
echo "Latest rav1e tag: $LATEST_RAV1E_TAG" # Should be like vX.Y.Z

LATEST_RAV1E_VERSION_NO_V=$(echo "$LATEST_RAV1E_TAG" | sed 's/^v//') # Remove 'v' prefix
checkStatus $? "Failed to parse rav1e version from tag (sed)"
echo "Latest rav1e version (no 'v'): $LATEST_RAV1E_VERSION_NO_V"

# download source
RAV1E_DOWNLOAD_URL="https://github.com/xiph/rav1e/archive/refs/tags/${LATEST_RAV1E_TAG}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name_without_v_prefix>
RAV1E_UNPACK_DIR="rav1e-${LATEST_RAV1E_VERSION_NO_V}"

download "$RAV1E_DOWNLOAD_URL" "rav1e.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "rav1e.tar.gz"
checkStatus $? "unpack failed"
cd "$RAV1E_UNPACK_DIR/"
checkStatus $? "change directory failed"

# install
cargo cinstall --library-type staticlib --release -j $CPUS --prefix "$TOOL_DIR" --libdir="$TOOL_DIR/lib"
checkStatus $? "build or installation failed"
