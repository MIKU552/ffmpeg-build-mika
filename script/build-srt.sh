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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/srt")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "srt"
checkStatus $? "create directory failed"
cd "srt/"
checkStatus $? "change directory failed"

# download source
download https://gh-proxy.com/https://github.com/Haivision/srt/archive/refs/tags/v$VERSION.tar.gz "srt.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "srt.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir srt_build
checkStatus $? "create build directory failed"
cd srt_build
checkStatus $? "change build directory failed"
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=OFF -DENABLE_APPS=OFF ../srt-$VERSION/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
