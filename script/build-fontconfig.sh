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

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "fontconfig"
checkStatus $? "create directory failed"
cd "fontconfig/"
checkStatus $? "change directory failed"

# Get latest fontconfig version
echo "Fetching latest fontconfig version..."
LATEST_FONTCONFIG_VERSION=$(curl -s https://www.freedesktop.org/software/fontconfig/release/ | grep -oP 'fontconfig-\d+\.\d+(\.\d+)?\.tar\.xz' | sed -E 's/fontconfig-(.*)\.tar\.xz/\1/' | sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest fontconfig version"
echo "Latest fontconfig version: $LATEST_FONTCONFIG_VERSION"

# download source
FONTCONFIG_TARBALL="fontconfig-$LATEST_FONTCONFIG_VERSION.tar.xz"
FONTCONFIG_UNPACK_DIR="fontconfig-$LATEST_FONTCONFIG_VERSION"
download https://www.freedesktop.org/software/fontconfig/release/$FONTCONFIG_TARBALL "$FONTCONFIG_TARBALL"
checkStatus $? "download failed"

# unpack
tar -xvf "$FONTCONFIG_TARBALL"
checkStatus $? "unpack failed"
cd "$FONTCONFIG_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-static=yes --enable-shared=no --enable-libxml2
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
