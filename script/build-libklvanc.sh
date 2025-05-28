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
mkdir "libklvanc"
checkStatus $? "create directory failed"
cd "libklvanc/"
checkStatus $? "change directory failed"

# Get latest libklvanc version from GitHub API
echo "Fetching latest libklvanc version from GitHub..."
LATEST_LIBKLVANC_TAG=$(curl -s https://api.github.com/repos/stoth68000/libklvanc/releases/latest | jq -r '.tag_name')
checkStatus $? "Failed to fetch latest libklvanc tag"
echo "Latest libklvanc tag: $LATEST_LIBKLVANC_TAG"

# The version part for the directory might need parsing if the tag includes more than just X.Y.Z
# However, the existing script uses "libklvanc-vid.obe.$VERSION", if the tag is "vid.obe.X.Y.Z",
# then the directory name is "libklvanc-${LATEST_LIBKLVANC_TAG}" if the tarball extracts like that,
# or more likely "libklvanc-vid.obe.X.Y.Z" if the source code within the tarball is named that way.
# The existing script structure "libklvanc-vid.obe.$VERSION" suggests the tarball contains a folder named "libklvanc-${LATEST_LIBKLVANC_TAG}"
# or the tar command renames it. Let's assume the tarball itself contains the folder name "libklvanc-${LATEST_LIBKLVANC_TAG}".

# download source
# The download URL uses the full tag.
LIBKLVANC_TARBALL_NAME="libklvanc-${LATEST_LIBKLVANC_TAG}.tar.gz" # Or just "libklvanc.tar.gz"
LIBKLVANC_DOWNLOAD_URL="https://github.com/stoth68000/libklvanc/archive/refs/tags/${LATEST_LIBKLVANC_TAG}.tar.gz"
# The directory created by tar -zxf is typically <repo_name>-<tag_name_without_slashes_or_refs_tags>
# For example, if tag is 'v1.2.3', directory is 'libklvanc-1.2.3'.
# If tag is 'vid.obe.1.2.3', directory is likely 'libklvanc-vid.obe.1.2.3'.
LIBKLVANC_UNPACK_DIR="libklvanc-${LATEST_LIBKLVANC_TAG}"

download $LIBKLVANC_DOWNLOAD_URL "libklvanc.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "libklvanc.tar.gz"
checkStatus $? "unpack failed"
cd "$LIBKLVANC_UNPACK_DIR/" # This is the crucial part for directory name
checkStatus $? "change directory failed"

# prepare build
./autogen.sh --build
checkStatus $? "autogen failed"
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
