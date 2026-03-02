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

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/zlib")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "zlib"
checkStatus $? "create directory failed"
cd "zlib/"
checkStatus $? "change directory failed"

# download source
download https://www.zlib.net/fossils/zlib-$VERSION.tar.gz "zlib.tar.gz"
checkStatus $? "download failed"

# unpacking
tar -zxf "zlib.tar.gz"
checkStatus $? "unpacking failed"
cd "zlib-$VERSION/"
checkStatus $? "change directory failed"

# 使用和主脚本一致的操作系统识别方式
OS_NAME=$(uname -s)
echo "detected OS: $OS_NAME"

if [[ "$OS_NAME" == MINGW* ]] || [[ "$OS_NAME" == MSYS* ]]; then
    echo "run windows specific build"

    # windows build
    make -j $CPUS -f win32/Makefile.gcc
    checkStatus $? "build failed"

    # install
    # 注意：win32/Makefile.gcc 官方并没有编写 install 逻辑，我们必须手动复制所需文件
    mkdir -p "$TOOL_DIR/include"
    mkdir -p "$TOOL_DIR/lib"
    cp -a zlib.h zconf.h "$TOOL_DIR/include/"
    cp -a libz.a "$TOOL_DIR/lib/"
    checkStatus $? "installation failed"
else
    # prepare build
    ./configure --prefix="$TOOL_DIR" --static
    checkStatus $? "configuration failed"

    # build
    make -j $CPUS
    checkStatus $? "build failed"

    # install
    make install
    checkStatus $? "installation failed"
fi