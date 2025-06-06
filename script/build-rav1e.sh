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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/rav1e")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "rav1e"
checkStatus $? "create directory failed"
cd "rav1e/"
checkStatus $? "change directory failed"

# download source
download https://gh-proxy.com/https://github.com/xiph/rav1e/archive/refs/tags/v$VERSION.tar.gz "rav1e.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "rav1e.tar.gz"
checkStatus $? "unpack failed"
cd "rav1e-$VERSION/"
checkStatus $? "change directory failed"

# install
cargo cinstall --library-type staticlib --release -j $CPUS --prefix "$TOOL_DIR" --libdir="$TOOL_DIR/lib"
checkStatus $? "build or installation failed"
