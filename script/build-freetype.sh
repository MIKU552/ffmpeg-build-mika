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

# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "freetype"
checkStatus $? "create directory failed"
cd "freetype/"
checkStatus $? "change directory failed"

# Get latest freetype version
echo "Fetching latest freetype version..."
LATEST_FREETYPE_VERSION=$(curl -s https://download.savannah.gnu.org/releases/freetype/ | grep -oP 'href="freetype-\d+\.\d+(\.\d+)?\.tar\.gz"' | grep -oP '\d+\.\d+(\.\d+)?' | sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest freetype version"
echo "Latest freetype version: $LATEST_FREETYPE_VERSION"

# download source
FREETYPE_TARBALL="freetype-$LATEST_FREETYPE_VERSION.tar.gz"
FREETYPE_UNPACK_DIR="freetype-$LATEST_FREETYPE_VERSION"
download https://download.savannah.gnu.org/releases/freetype/$FREETYPE_TARBALL "$FREETYPE_TARBALL"
if [ $? -ne 0 ]; then
    echo "Download from savannah.gnu.org failed; trying SourceForge mirror"
    # Note: SourceForge URL structure might be less stable for automated fetching of latest.
    # This attempts to use the fetched version, but might fail if SF changes its path structure.
    download https://sourceforge.net/projects/freetype/files/freetype2/$LATEST_FREETYPE_VERSION/$FREETYPE_TARBALL/download "$FREETYPE_TARBALL"
    checkStatus $? "Download from SourceForge mirror failed"
fi

# unpack
tar -zxf "$FREETYPE_TARBALL"
checkStatus $? "unpack failed"
cd "$FREETYPE_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
