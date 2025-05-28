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
mkdir "fribidi"
checkStatus $? "create directory failed"
cd "fribidi/"
checkStatus $? "change directory failed"

# Get latest fribidi version from GitHub API
echo "Fetching latest fribidi version from GitHub..."
LATEST_FRIBIDI_TAG=$(curl -s https://api.github.com/repos/fribidi/fribidi/releases/latest | jq -r '.tag_name')
checkStatus $? "Failed to fetch latest fribidi tag"
# Version for directory and tarball name usually doesn't have 'v'
LATEST_FRIBIDI_VERSION=$(echo "$LATEST_FRIBIDI_TAG" | sed 's/^v//')
checkStatus $? "Failed to parse fribidi version from tag"
echo "Latest fribidi version: $LATEST_FRIBIDI_VERSION (tag: $LATEST_FRIBIDI_TAG)"

# download source
FRIBIDI_TARBALL="fribidi-$LATEST_FRIBIDI_VERSION.tar.xz"
FRIBIDI_UNPACK_DIR="fribidi-$LATEST_FRIBIDI_VERSION"
download https://github.com/fribidi/fribidi/releases/download/$LATEST_FRIBIDI_TAG/$FRIBIDI_TARBALL "$FRIBIDI_TARBALL"
checkStatus $? "download failed"

# unpack
tar -xf "$FRIBIDI_TARBALL"
checkStatus $? "unpack failed"
cd "$FRIBIDI_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
