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
mkdir "libass"
checkStatus $? "create directory failed"
cd "libass/"
checkStatus $? "change directory failed"

# Get latest libass version from GitHub API
echo "Fetching latest libass version from GitHub..."
LATEST_LIBASS_TAG=$(get_latest_github_release_tag "libass/libass")
checkStatus $? "Failed to fetch latest libass tag from GitHub"
# Assuming tag is the version number itself (e.g., 0.17.1)
LATEST_LIBASS_VERSION="$LATEST_LIBASS_TAG"
echo "Latest libass version: $LATEST_LIBASS_VERSION"

# download source
LIBASS_TARBALL="libass-${LATEST_LIBASS_VERSION}.tar.gz"
LIBASS_UNPACK_DIR="libass-${LATEST_LIBASS_VERSION}"
download "https://github.com/libass/libass/releases/download/${LATEST_LIBASS_TAG}/${LIBASS_TARBALL}" "$LIBASS_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$LIBASS_TARBALL"
checkStatus $? "unpack failed"
cd "$LIBASS_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
