#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "$SCRIPT_DIR/functions.sh"

SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3

OS_NAME=$(uname -s)
VERSION=$(cat "$SCRIPT_DIR/../version/ffnvcodec")
echo "ffnvcodec version: $VERSION"

cd "$SOURCE_DIR"
if [ ! -d "nv-codec-headers" ]; then
    git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
fi
cd nv-codec-headers
git fetch --all --tags
git checkout "n$VERSION"

make PREFIX="$TOOL_DIR" install
checkStatus $? "ffnvcodec make install failed"