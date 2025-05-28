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
mkdir "dav1d"
checkStatus $? "create directory failed"
cd "dav1d/"
checkStatus $? "change directory failed"

# Get latest dav1d version from VideoLAN GitLab API
echo "Fetching latest dav1d version from VideoLAN GitLab API..."
LATEST_DAV1D_TAG=$(get_latest_gitlab_release_tag "code.videolan.org/videolan%2Fdav1d")
checkStatus $? "Failed to fetch latest dav1d tag from GitLab"
# Assuming tag is the version number itself (e.g., 1.2.1)
LATEST_DAV1D_VERSION="$LATEST_DAV1D_TAG"
echo "Latest dav1d version: $LATEST_DAV1D_VERSION"

# download source
DAV1D_TARBALL="dav1d-${LATEST_DAV1D_VERSION}.tar.gz"
DAV1D_UNPACK_DIR="dav1d-${LATEST_DAV1D_VERSION}"
download "https://code.videolan.org/videolan/dav1d/-/archive/${LATEST_DAV1D_TAG}/${DAV1D_TARBALL}" "${DAV1D_TARBALL}"
checkStatus $? "download failed"

# unpack
tar -zxf "${DAV1D_TARBALL}"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "${DAV1D_UNPACK_DIR}/"
checkStatus $? "change directory failed"
# Enable LTO for dav1d using Meson option
meson build --prefix "$TOOL_DIR" --libdir=lib --default-library=static -Db_lto=true
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"