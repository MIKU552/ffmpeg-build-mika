#!/bin/sh

# Copyright 2022 Martin Riedl
# Merged for Linux & macOS compatibility

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

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "libvorbis" # Use -p
cd "libvorbis/"
checkStatus $? "change directory failed"

# Get latest libvorbis version from Xiph.org
echo "Fetching latest libvorbis version from Xiph.org..."
LATEST_LIBVORBIS_VERSION=$(get_latest_html_link_version \
    "https://downloads.xiph.org/releases/vorbis/" \
    'href="libvorbis-([0-9\.]+)\.tar\.(gz|xz|bz2)"' \
    's|.*libvorbis-([0-9\.]+)\.tar\.(gz|xz|bz2).*|\1|')
checkStatus $? "Failed to fetch latest libvorbis version"
echo "Latest libvorbis version: $LATEST_LIBVORBIS_VERSION"

# Determine tarball extension
LIBVORBIS_TARBALL_EXT=$(determine_tarball_extension \
    "https://downloads.xiph.org/releases/vorbis/libvorbis-${LATEST_LIBVORBIS_VERSION}" \
    ".tar.gz") # Default to .tar.gz
checkStatus $? "Failed to determine tarball extension for libvorbis"
echo "Using extension: $LIBVORBIS_TARBALL_EXT"

# download source
LIBVORBIS_TARBALL="libvorbis-${LATEST_LIBVORBIS_VERSION}${LIBVORBIS_TARBALL_EXT}"
LIBVORBIS_UNPACK_DIR="libvorbis-${LATEST_LIBVORBIS_VERSION}"
download "https://ftp.osuosl.org/pub/xiph/releases/vorbis/${LIBVORBIS_TARBALL}" "$LIBVORBIS_TARBALL"
checkStatus $? "download failed"

# unpack
if [ "$LIBVORBIS_TARBALL_EXT" = ".tar.xz" ]; then
    tar -xf "$LIBVORBIS_TARBALL"
elif [ "$LIBVORBIS_TARBALL_EXT" = ".tar.bz2" ]; then
    tar -xjf "$LIBVORBIS_TARBALL"
else # .tar.gz
    tar -zxf "$LIBVORBIS_TARBALL"
fi
checkStatus $? "unpack failed"
cd "$LIBVORBIS_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
# Apply macOS specific sed changes only on Darwin
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS specific configure patches..."
    run_sed '205,207s/-force_cpusubtype_ALL //g' configure.ac
    run_sed '12843,12845s/-force_cpusubtype_ALL //g' configure
fi

./configure --prefix="$TOOL_DIR" --enable-shared=no --disable-examples --disable-docs
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"