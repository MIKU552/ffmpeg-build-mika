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

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libbluray"
checkStatus $? "create directory failed"
cd "libbluray/"
checkStatus $? "change directory failed"

# Get latest libbluray version from VideoLAN FTP
echo "Fetching latest libbluray version from VideoLAN FTP..."
LATEST_LIBBLURAY_VERSION=$(get_latest_html_link_version \
    "https://download.videolan.org/pub/videolan/libbluray/" \
    'href="([0-9\.]+)/"' \
    's|href="([0-9\.]+)/"|\1|')
checkStatus $? "Failed to fetch latest libbluray version"
echo "Latest libbluray version: $LATEST_LIBBLURAY_VERSION"

# download source
LIBBLURAY_TARBALL="libbluray-${LATEST_LIBBLURAY_VERSION}.tar.bz2" # Assumes .tar.bz2 based on previous script
LIBBLURAY_UNPACK_DIR="libbluray-${LATEST_LIBBLURAY_VERSION}"
download "https://download.videolan.org/pub/videolan/libbluray/${LATEST_LIBBLURAY_VERSION}/${LIBBLURAY_TARBALL}" "$LIBBLURAY_TARBALL"
checkStatus $? "download failed"

# unpack
bunzip2 "$LIBBLURAY_TARBALL"
checkStatus $? "unpack failed (bunzip2)"
# The tarball name after bunzip2 will be the tarball name without .bz2
tar -xf $(basename "$LIBBLURAY_TARBALL" .bz2)
checkStatus $? "unpack failed (tar)"
cd "$LIBBLURAY_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no --disable-bdjava-jar
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
