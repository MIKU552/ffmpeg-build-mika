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
mkdir "snappy"
checkStatus $? "create directory failed"
cd "snappy/"
checkStatus $? "change directory failed"

# Get latest snappy version from GitHub API
echo "Fetching latest snappy version from GitHub..."
LATEST_SNAPPY_VERSION=$(get_latest_github_release_tag "google/snappy")
checkStatus $? "Failed to fetch latest snappy version from GitHub"
echo "Latest snappy version: $LATEST_SNAPPY_VERSION" # Should be like X.Y.Z

# download source
SNAPPY_DOWNLOAD_URL="https://github.com/google/snappy/archive/refs/tags/${LATEST_SNAPPY_VERSION}.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name>
SNAPPY_UNPACK_DIR_ROOT="snappy-${LATEST_SNAPPY_VERSION}"

download "$SNAPPY_DOWNLOAD_URL" "snappy.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "snappy.tar.gz"
checkStatus $? "unpack failed"
# Note: The tarball unpacks to snappy-${LATEST_SNAPPY_VERSION}
# The build will happen in a subdirectory.

# prepare build
mkdir snappy_build
checkStatus $? "create build directory failed"
cd snappy_build
checkStatus $? "change build directory failed"
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DSNAPPY_BUILD_BENCHMARKS=OFF -DSNAPPY_BUILD_TESTS=OFF ../$SNAPPY_UNPACK_DIR_ROOT/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
