#!/bin/bash

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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/freetype")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "freetype"
checkStatus $? "create directory failed"
cd "freetype/"
checkStatus $? "change directory failed"

# download source
download https://download.savannah.gnu.org/releases/freetype/freetype-$VERSION.tar.gz "freetype.tar.gz"
if [ $? -ne 0 ]; then
    echo "download failed; start download from mirror server"
    download https://sourceforge.net/projects/freetype/files/freetype2/$VERSION/freetype-$VERSION.tar.gz/download "freetype.tar.gz"
    checkStatus $? "download failed"
fi

# unpack
tar -zxf "freetype.tar.gz"
checkStatus $? "unpack failed"
cd "freetype-$VERSION/"
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
