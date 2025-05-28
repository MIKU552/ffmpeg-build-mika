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

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libtheora"
checkStatus $? "create directory failed"
cd "libtheora/"
checkStatus $? "change directory failed"

# Get latest libtheora version from Xiph.org
echo "Fetching latest libtheora version from Xiph.org..."
LATEST_LIBTHEORA_VERSION=$(get_latest_html_link_version \
    "https://downloads.xiph.org/releases/theora/" \
    'href="libtheora-([0-9\.\-a-zA-Z]+)\.tar\.(gz|xz|bz2)"' \
    's|.*libtheora-([0-9\.\-a-zA-Z]+)\.tar\.(gz|xz|bz2).*|\1|' \
    '^[0-9]+\.[0-9]+(\.[0-9\.\-a-zA-Z])*$') # More flexible version filter for alphas/betas like 1.2.0alpha1
checkStatus $? "Failed to fetch latest libtheora version"
echo "Latest libtheora version: $LATEST_LIBTHEORA_VERSION"

# Determine tarball extension
LIBTHEORA_TARBALL_EXT=$(determine_tarball_extension \
    "https://downloads.xiph.org/releases/theora/libtheora-${LATEST_LIBTHEORA_VERSION}" \
    ".tar.xz") # Default to .tar.xz as per previous script version
checkStatus $? "Failed to determine tarball extension for libtheora"
echo "Using extension: $LIBTHEORA_TARBALL_EXT"

# download source
LIBTHEORA_TARBALL="libtheora-${LATEST_LIBTHEORA_VERSION}${LIBTHEORA_TARBALL_EXT}"
LIBTHEORA_UNPACK_DIR="libtheora-${LATEST_LIBTHEORA_VERSION}"
download "http://downloads.xiph.org/releases/theora/${LIBTHEORA_TARBALL}" "$LIBTHEORA_TARBALL"
checkStatus $? "download failed"

# unpack
if [ "$LIBTHEORA_TARBALL_EXT" = ".tar.xz" ]; then
    tar -xvf "$LIBTHEORA_TARBALL"
elif [ "$LIBTHEORA_TARBALL_EXT" = ".tar.bz2" ]; then
    tar -xjf "$LIBTHEORA_TARBALL"
else # .tar.gz
    tar -zxf "$LIBTHEORA_TARBALL"
fi
checkStatus $? "unpack (tar)"
cd "$LIBTHEORA_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no --disable-oggtest --disable-vorbistest --disable-sdltest
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
