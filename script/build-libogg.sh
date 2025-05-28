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
mkdir "libogg"
checkStatus $? "create directory failed"
cd "libogg/"
checkStatus $? "change directory failed"

# Get latest libogg version from Xiph.org
echo "Fetching latest libogg version from Xiph.org..."
LATEST_LIBOGG_VERSION=$(get_latest_html_link_version \
    "https://downloads.xiph.org/releases/ogg/" \
    'href="libogg-([0-9\.]+)\.tar\.(gz|xz|bz2)"' \
    's|.*libogg-([0-9\.]+)\.tar\.(gz|xz|bz2).*|\1|')
checkStatus $? "Failed to fetch latest libogg version"
echo "Latest libogg version: $LATEST_LIBOGG_VERSION"

# Determine tarball extension
LIBOGG_TARBALL_EXT=$(determine_tarball_extension \
    "https://downloads.xiph.org/releases/ogg/libogg-${LATEST_LIBOGG_VERSION}" \
    ".tar.gz") # Default to .tar.gz
checkStatus $? "Failed to determine tarball extension for libogg"
echo "Using extension: $LIBOGG_TARBALL_EXT"

# download source
LIBOGG_TARBALL="libogg-${LATEST_LIBOGG_VERSION}${LIBOGG_TARBALL_EXT}"
LIBOGG_UNPACK_DIR="libogg-${LATEST_LIBOGG_VERSION}"
# Using OSUOSL mirror with the fetched version and determined extension
download "https://ftp.osuosl.org/pub/xiph/releases/ogg/${LIBOGG_TARBALL}" "$LIBOGG_TARBALL"
checkStatus $? "download failed"

# unpack
if [ "$LIBOGG_TARBALL_EXT" = ".tar.xz" ]; then
    tar -xf "$LIBOGG_TARBALL"
elif [ "$LIBOGG_TARBALL_EXT" = ".tar.bz2" ]; then
    tar -xjf "$LIBOGG_TARBALL"
else # .tar.gz
    tar -zxf "$LIBOGG_TARBALL"
fi
checkStatus $? "unpack failed"
cd "$LIBOGG_UNPACK_DIR/"
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
