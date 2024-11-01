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
VERSION=$(cat "$SCRIPT_DIR/../version/vvdec")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "vvdec"
checkStatus $? "create directory failed"
cd "vvdec/"
checkStatus $? "change directory failed"

# download source
download https://github.com/fraunhoferhhi/vvdec/archive/refs/tags/v$VERSION.tar.gz "vvdec.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "vvdec.tar.gz"
checkStatus $? "unpack failed"

# prepare build
cd "vvdec-$VERSION/"
checkStatus $? "change directory failed"

# build
make g=ninja -j $CPUS release-shared
checkStatus $? "build failed"

# install
make g=ninja install install-prefix=$TOOL_DIR
checkStatus $? "installation failed"

# it seems install-prefix is currently not working
cp -r install/* $TOOL_DIR/