#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "$SCRIPT_DIR/functions.sh"

SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

VERSION=$(cat "$SCRIPT_DIR/../version/vpl")
echo "vpl version: $VERSION"

cd "$SOURCE_DIR"
if [ ! -d "libvpl" ]; then
    git clone https://github.com/intel/libvpl.git
fi
cd libvpl
git fetch --all --tags
git checkout "v$VERSION"

rm -rf build && mkdir build && cd build
# 强制静态编译 Dispatcher
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF
checkStatus $? "vpl cmake failed"

make -j"$CPUS" install
checkStatus $? "vpl make install failed"

# 补全 pkg-config 静态依赖 (依赖 C++ 库)
VPL_PC="$TOOL_DIR/lib/pkgconfig/vpl.pc"
if [ -f "$VPL_PC" ]; then
    run_sed "s|-lvpl|-lvpl -lstdc++|g" "$VPL_PC"
fi