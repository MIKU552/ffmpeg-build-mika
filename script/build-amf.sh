#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "$SCRIPT_DIR/functions.sh"

SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3

VERSION=$(cat "$SCRIPT_DIR/../version/amf")
echo "amf version: $VERSION"

cd "$SOURCE_DIR"
if [ ! -d "AMF" ]; then
    git clone https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git
fi
cd AMF
git fetch --all --tags
git checkout "v$VERSION"

# AMF 纯靠头文件，无需编译，直接复制到 include 目录即可
mkdir -p "$TOOL_DIR/include/AMF"
cp -r amf/public/include/* "$TOOL_DIR/include/AMF/"
checkStatus $? "AMF headers copy failed"