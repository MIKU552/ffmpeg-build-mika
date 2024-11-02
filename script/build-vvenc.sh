#!/bin/sh

# Copyright 2024 Hayden Zheng
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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/vvenc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "vvenc"
checkStatus $? "create directory failed"
cd "vvenc/"
checkStatus $? "change directory failed"

# download source
download https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v$VERSION.tar.gz "vvenc.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "vvenc.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
cd "build/"
checkStatus $? "change directory failed"
cmake -S ../vvenc-$VERSION -B build/release-static -G 'Ninja' -DCMAKE_INSTALL_PREFIX=$TOOL_DIR -DCMAKE_BUILD_TYPE=Release

# build
cmake --build build/release-static -j $CPUS
checkStatus $? "build failed"

# install
cmake --build build/release-static --target install
checkStatus $? "installation failed"
