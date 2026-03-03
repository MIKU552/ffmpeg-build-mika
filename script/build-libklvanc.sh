#!/bin/bash

# build-libklvanc.sh
# 修复了 autogen 参数错误和 Windows 头文件缺失问题

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
# 【关键修复 1】Windows MinGW 环境下缺少 sys/errno.h 的兼容性补丁
# 原因：MinGW 使用标准的 <errno.h>，没有 POSIX 的 <sys/errno.h>
# =========================================================
OS_DETECT=$(uname -s)
if [[ "$OS_DETECT" == MINGW* ]] || [[ "$OS_DETECT" == MSYS* ]]; then
    echo "Creating compatibility patch: replacing <sys/errno.h> with <errno.h>"
    # 批量替换源码中的头文件引用
    sed -i 's|<sys/errno.h>|<errno.h>|g' src/libklvanc/vanc.h
    checkStatus $? "sed patch failed"
fi
# =========================================================

# prepare build
echo "Running autoreconf..."
# 【关键修复 2】直接调用 autoreconf，不传任何多余参数
# -f: force (强制重新生成)
# -i: install (安装缺失的辅助文件)
# -v: verbose (显示详细信息)
autoreconf -fiv
checkStatus $? "autoreconf failed"

# configure
# 显式禁用 shared，启用 static，确保生成静态库
./configure --prefix="$TOOL_DIR" --enable-shared=no --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"