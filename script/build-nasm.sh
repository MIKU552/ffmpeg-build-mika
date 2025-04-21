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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/nasm")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "nasm"
checkStatus $? "create directory failed"
cd "nasm/"
checkStatus $? "change directory failed"

# download source
mkdir "nasm"
checkStatus $? "create directory failed"
download http://www.nasm.us/pub/nasm/releasebuilds/$VERSION/nasm-$VERSION.tar.gz nasm.tar.gz
if [ $? -ne 0 ]; then
    echo "download failed; start download from github server"
    download https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-$VERSION.tar.gz nasm.tar.gz
    checkStatus $? "download failed"
fi

# unpack
tar -zxf "nasm.tar.gz" -C nasm --strip-components=1
checkStatus $? "unpack failed"
cd "nasm/"
checkStatus $? "change directory failed"

# prepare build
if [ -f "configure" ]; then
    echo "configure file found; continue"
else
    echo "run autogen first"
    ./autogen.sh
    checkStatus "autogen failed"
fi
./configure --prefix="$TOOL_DIR"
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
echo "Creating dummy nasm.1 to avoid installation error..." # 添加说明信息
touch ./nasm.1 # <--- 新增行：创建空的 nasm.1 文件
touch ./ndisasm.1 # <--- 新增行：创建空的 ndisasm.1 文件


# install
make install
checkStatus $? "installation failed"
