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
VERSION=$(cat "$SCRIPT_DIR/../version/libvmaf")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libvmaf"
checkStatus $? "create directory failed"
cd "libvmaf/"
checkStatus $? "change directory failed"

# download source
download https://github.com/Netflix/vmaf/archive/refs/tags/v$VERSION.tar.gz "libvmaf.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libvmaf.tar.gz"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "vmaf-$VERSION/libvmaf/"
checkStatus $? "change directory failed"
meson build --prefix "$TOOL_DIR" --libdir=lib --buildtype release --default-library static
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"

# post-installation
# static linking fails because c++ dependency is missing in pc file (pkg-config file)
# https://github.com/Netflix/vmaf/issues/788
sed -i.original -e 's/lvmaf/lvmaf -lstdc++/g' $TOOL_DIR/lib/pkgconfig/libvmaf.pc
checkStatus $? "modify pkg-config .pc file failed"
