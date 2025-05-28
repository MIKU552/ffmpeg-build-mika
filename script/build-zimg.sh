#!/bin/sh

# Copyright 2023 Martin Riedl
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
mkdir -p "zimg" # Use -p
cd "zimg/"
checkStatus $? "change directory failed"

# Get latest zimg version from GitHub API
echo "Fetching latest zimg version from GitHub..."
LATEST_ZIMG_TAG=$(get_latest_github_release_tag "sekrit-twc/zimg")
checkStatus $? "Failed to fetch latest zimg tag from GitHub"
echo "Latest zimg tag: $LATEST_ZIMG_TAG" # Should be like release-X.Y.Z

# download source
# Tarball name can be kept simple, download URL uses the tag.
ZIMG_TARBALL="zimg-latest.tar.gz"
# The directory created by tar -zxf for GitHub archives is typically <repo_name>-<tag_name>
# e.g. zimg-release-3.0.5 if tag is release-3.0.5. This matches the existing ZIMG_UNPACK_DIR logic.
ZIMG_UNPACK_DIR="zimg-${LATEST_ZIMG_TAG}"
ZIMG_DOWNLOAD_URL="https://github.com/sekrit-twc/zimg/archive/refs/tags/${LATEST_ZIMG_TAG}.tar.gz"

download "$ZIMG_DOWNLOAD_URL" "$ZIMG_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$ZIMG_TARBALL"
checkStatus $? "unpack failed"
rm "$ZIMG_TARBALL" # Clean up
cd "$ZIMG_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./autogen.sh
checkStatus $? "autogen failed"
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# --- Post-installation pkg-config fix ---
# build fails on some OS, because of missing linking to libm
echo "Applying post-installation fix to zimg.pc..."
# Determine where the .pc file was installed
PKGCONFIG_PATH_LIB="$TOOL_DIR/lib/pkgconfig/zimg.pc"
PKGCONFIG_PATH_LIB64="$TOOL_DIR/lib64/pkgconfig/zimg.pc"
ACTUAL_PC_FILE=""

if [ -f "$PKGCONFIG_PATH_LIB" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB"
elif [ "$OS_NAME" = "Linux" ] && [ -f "$PKGCONFIG_PATH_LIB64" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB64"
fi

if [ -z "$ACTUAL_PC_FILE" ]; then
    echo "Warning: zimg.pc not found in expected pkgconfig directories after install!"
else
     echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
     # Add -lm if missing
     if ! grep -q -- "-lm" "$ACTUAL_PC_FILE"; then
         echo "Adding -lm to $ACTUAL_PC_FILE"
         # Append to Libs.private if it exists, otherwise append to Libs
         if grep -q "^Libs.private:" "$ACTUAL_PC_FILE"; then
             run_sed "s|^Libs.private:.*|& -lm|" "$ACTUAL_PC_FILE"
         else
             run_sed "s|^Libs:.*|& -lm|" "$ACTUAL_PC_FILE"
         fi
          checkStatus $? "modify pkgconfig file failed"
     else
          echo "-lm already seems present in $ACTUAL_PC_FILE."
     fi
fi

cd .. # Back to SOURCE_DIR/zimg