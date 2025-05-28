#!/bin/sh

# Copyright 2023 Martin Riedl
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
mkdir "libiconv"
checkStatus $? "create directory failed"
cd "libiconv/"
checkStatus $? "change directory failed"

# Get latest libiconv version from GNU FTP
echo "Fetching latest libiconv version from GNU FTP..."
LATEST_LIBICONV_VERSION=$(get_latest_html_link_version \
    "https://ftp.gnu.org/pub/gnu/libiconv/" \
    'href="libiconv-([0-9\.]+)\.tar\.gz"' \
    's|.*libiconv-([0-9\.]+)\.tar\.gz.*|\1|')
checkStatus $? "Failed to fetch latest libiconv version"
echo "Latest libiconv version: $LATEST_LIBICONV_VERSION"

# download source
LIBICONV_TARBALL="libiconv-${LATEST_LIBICONV_VERSION}.tar.gz" # Assumes .tar.gz, common for GNU
LIBICONV_UNPACK_DIR="libiconv-${LATEST_LIBICONV_VERSION}"
download "https://ftp.gnu.org/pub/gnu/libiconv/${LIBICONV_TARBALL}" "$LIBICONV_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$LIBICONV_TARBALL"
checkStatus $? "unpack failed"
cd "$LIBICONV_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
# shared version is required for some library builds (like zvbi)
./configure --prefix="$TOOL_DIR" --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
