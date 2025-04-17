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
VERSION=$(cat "$SCRIPT_DIR/../version/openjpeg")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openjpeg"
checkStatus $? "create directory failed"
cd "openjpeg/"
checkStatus $? "change directory failed"

# download source
download https://gh-proxy.com/https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "openjpeg.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openjpeg.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir openjpeg_build
checkStatus $? "create build directory failed"
cd openjpeg_build
checkStatus $? "change build directory failed"
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$TOOL_DIR -DBUILD_SHARED_LIBS=OFF ../openjpeg-$VERSION/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# post-installation
# modify pkg-config file for usage with ffmpeg (it seems that the flag for threads is missing)
sed -i.original -e 's/lopenjp2/lopenjp2 -lpthread/g' $TOOL_DIR/lib/pkgconfig/libopenjp2.pc
