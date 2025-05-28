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
mkdir "libxml2"
checkStatus $? "create directory failed"
cd "libxml2/"
checkStatus $? "change directory failed"

# Get latest libxml2 version from GitLab API
echo "Fetching latest libxml2 version from GitLab API..."
LATEST_LIBXML2_TAG=$(get_latest_gitlab_release_tag "gitlab.gnome.org/GNOME%2Flibxml2")
checkStatus $? "Failed to fetch latest libxml2 tag from GitLab"
echo "Latest libxml2 tag: $LATEST_LIBXML2_TAG" # Should be like vX.Y.Z

# download source
# The tarball name from GitLab archive URL typically uses the tag directly.
LIBXML2_TARBALL_NAME="libxml2-${LATEST_LIBXML2_TAG}.tar.gz"
LIBXML2_DOWNLOAD_URL="https://gitlab.gnome.org/GNOME/libxml2/-/archive/${LATEST_LIBXML2_TAG}/${LIBXML2_TARBALL_NAME}"
# The directory created by tar -zxf is typically <repo_name>-<tag_name_with_commit_sha_if_not_a_clean_tag>
# For libxml2, if tag is v2.9.14, directory is libxml2-v2.9.14
LIBXML2_UNPACK_DIR="libxml2-${LATEST_LIBXML2_TAG}"

download "$LIBXML2_DOWNLOAD_URL" "libxml2.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "libxml2.tar.gz"
checkStatus $? "unpack failed"
cd "$LIBXML2_UNPACK_DIR/"
checkStatus $? "change directory failed"

# check for pre-generated configure file
if [ -f "configure" ]; then
    echo "use existing configure file"
else
    ACLOCAL_PATH=$TOOL_DIR/share/aclocal NOCONFIGURE=YES ./autogen.sh
    checkStatus $? "autogen failed"
fi

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no --without-python
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
