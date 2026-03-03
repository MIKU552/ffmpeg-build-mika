#!/bin/bash

# build-libklvanc.sh
# Copyright 2023 Martin Riedl & Modified for Windows Compatibility
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
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/libklvanc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "libklvanc"
checkStatus $? "create directory failed"
cd "libklvanc/"
checkStatus $? "change directory failed"

# download source
download https://github.com/stoth68000/libklvanc/archive/refs/tags/vid.obe.$VERSION.tar.gz "libklvanc.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libklvanc.tar.gz"
checkStatus $? "unpack failed"
cd "libklvanc-vid.obe.$VERSION/"
checkStatus $? "change directory failed"

# =========================================================
# 【修复】Windows MinGW 环境下缺少 sys/errno.h 的兼容性补丁
# 原因：MinGW 使用标准的 <errno.h>，没有 POSIX 的 <sys/errno.h>
# 修复：在子脚本内重新检测 OS，确保补丁一定会被执行
# =========================================================
OS_DETECT=$(uname -s)
if [[ "$OS_DETECT" == MINGW* ]] || [[ "$OS_DETECT" == MSYS* ]]; then
    echo "Creating compatibility patch: replacing <sys/errno.h> with <errno.h>"
    # 使用 sed 批量替换头文件引用
    sed -i 's|<sys/errno.h>|<errno.h>|g' src/libklvanc/vanc.h
    checkStatus $? "sed patch failed"
fi
# =========================================================

# prepare build
# 使用 --build-noconfigure 避免 autogen 自动运行 configure (我们下面自己配参数跑)
./autogen.sh --build-noconfigure
checkStatus $? "autogen failed"

# configure
# 显式禁用 shared 库，确保生成静态库 libklvanc.a
./configure --prefix="$TOOL_DIR" --enable-shared=no --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"