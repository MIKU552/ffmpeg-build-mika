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
mkdir "libvmaf"
checkStatus $? "create directory failed"
cd "libvmaf/"
checkStatus $? "change directory failed"

# Get latest libvmaf version from GitHub API
echo "Fetching latest libvmaf version from GitHub..."
LATEST_LIBVMAF_TAG=$(get_latest_github_release_tag "Netflix/vmaf")
checkStatus $? "Failed to fetch latest libvmaf tag from GitHub"
echo "Latest libvmaf tag: $LATEST_LIBVMAF_TAG" # Should be like vX.Y.Z

# Version for directory name usually doesn't have 'v'
LATEST_LIBVMAF_VERSION_NO_V=$(echo "$LATEST_LIBVMAF_TAG" | sed 's/^v//') # Remove 'v' prefix
checkStatus $? "Failed to parse libvmaf version from tag (sed)"
echo "Latest libvmaf version (no 'v'): $LATEST_LIBVMAF_VERSION_NO_V"

# download source
# GitHub archives are typically refs/tags/TAG_NAME.tar.gz
LIBVMAF_DOWNLOAD_URL="https://github.com/Netflix/vmaf/archive/refs/tags/${LATEST_LIBVMAF_TAG}.tar.gz"
# The directory created by tar -zxf is typically <repo_name>-<tag_name_without_v_prefix>
# For vmaf, if tag is v2.3.0, directory is vmaf-2.3.0. If tag is just 2.3.0, dir is vmaf-2.3.0
LIBVMAF_UNPACK_DIR_ROOT="vmaf-${LATEST_LIBVMAF_VERSION_NO_V}"

download "$LIBVMAF_DOWNLOAD_URL" "libvmaf.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "libvmaf.tar.gz"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "$LIBVMAF_UNPACK_DIR_ROOT/libvmaf/" # Path includes the libvmaf subdirectory
checkStatus $? "change directory failed"
meson build --prefix "$TOOL_DIR" --libdir=lib --buildtype release --default-library static
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"

# post-installation
# static linking fails because c++ dependency is missing in pc file (pkg-config file)
# https://github.com/Netflix/vmaf/issues/788
sed -i.original -e 's/lvmaf/lvmaf -lstdc++/g' $TOOL_DIR/lib/pkgconfig/libvmaf.pc
checkStatus $? "modify pkg-config .pc file failed"
