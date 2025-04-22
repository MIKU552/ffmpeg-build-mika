#!/bin/sh

# Copyright 2022 Martin Riedl
# Merged for Linux & macOS compatibility

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

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/libvorbis")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "libvorbis" # Use -p
cd "libvorbis/"
checkStatus $? "change directory failed"

# download source
download https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-$VERSION.tar.gz "libvorbis.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libvorbis.tar.gz"
checkStatus $? "unpack failed"
cd "libvorbis-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
# Apply macOS specific sed changes only on Darwin
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS specific configure patches..."
    run_sed '205,207s/-force_cpusubtype_ALL //g' configure.ac
    run_sed '12843,12845s/-force_cpusubtype_ALL //g' configure
fi

./configure --prefix="$TOOL_DIR" --enable-shared=no --disable-examples --disable-docs
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"