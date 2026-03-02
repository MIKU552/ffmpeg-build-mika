#!/bin/bash
# script/build-fdk-aac.sh

# ---
# Functions
# ---
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
# shellcheck source=../script/functions.sh
. "$SCRIPT_DIR/functions.sh"

# ---
# Main
# ---

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# detect OS
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/fdk-aac")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
mkdir -p "fdk-aac"
cd "fdk-aac/"

# download source
FDK_AAC_TARBALL="fdk-aac-$VERSION.tar.gz"
FDK_AAC_UNPACK_DIR="fdk-aac-$VERSION"
download "https://github.com/mstorsjo/fdk-aac/archive/v$VERSION.tar.gz" "$FDK_AAC_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$FDK_AAC_TARBALL"
checkStatus $? "unpack failed"
rm "$FDK_AAC_TARBALL"

# build
cd "$FDK_AAC_UNPACK_DIR/"

echo "Running autoreconf..."
autoreconf -fiv
checkStatus $? "autoreconf failed"

echo "Configuring fdk-aac..."
./configure \
    --prefix="$TOOL_DIR" \
    --enable-static \
    --disable-shared
checkStatus $? "configure failed"

echo "Compiling fdk-aac..."
make -j"$CPUS"
checkStatus $? "make failed"

echo "Installing fdk-aac..."
make install
checkStatus $? "make install failed"

# --- Post-installation pkg-config fix (解决 FFmpeg 静态链接时的 C++ 依赖问题) ---
echo "Applying post-installation fix to fdk-aac.pc for static linking..."
FDK_AAC_PC="$TOOL_DIR/lib/pkgconfig/fdk-aac.pc"
if [ -f "$FDK_AAC_PC" ]; then
    echo "Found pkgconfig file at: $FDK_AAC_PC"
    
    # fdk-aac 是 C++ 编写的，提供 C 接口。FFmpeg 在静态链接时经常漏掉 C++ 标准库
    if [ "$OS_NAME" = "Darwin" ]; then
        run_sed "s|-lfdk-aac|-lfdk-aac -lc++ -lm|g" "$FDK_AAC_PC"
    else
        run_sed "s|-lfdk-aac|-lfdk-aac -lstdc++ -lm|g" "$FDK_AAC_PC"
    fi
    checkStatus $? "modify pkgconfig file failed"
    echo "Dependencies successfully added to $FDK_AAC_PC"
else
    echo "Warning: fdk-aac.pc not found!"
fi