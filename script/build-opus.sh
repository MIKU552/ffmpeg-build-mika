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
mkdir "opus"
checkStatus $? "create directory failed"
cd "opus/"
checkStatus $? "change directory failed"

# Get latest opus version from Xiph.org
echo "Fetching latest opus version from Xiph.org..."
# This command looks for href="opus-X.Y.Z.tar.gz", extracts X.Y.Z, sorts, and takes the latest.
LATEST_OPUS_VERSION=$(curl -sL https://downloads.xiph.org/releases/opus/ | \
    grep -oP 'href="opus-([0-9\.]+)\.tar\.gz"' | \
    sed -E 's|href="opus-([0-9\.]+)\.tar\.gz"|\1|' | \
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)*$' | \
    sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest opus version"
echo "Latest opus version: $LATEST_OPUS_VERSION"

# download source
OPUS_PRIMARY_URL="https://downloads.xiph.org/releases/opus/opus-${LATEST_OPUS_VERSION}.tar.gz"
OPUS_GITLAB_URL="https://gitlab.xiph.org/xiph/opus/-/archive/v${LATEST_OPUS_VERSION}/opus-v${LATEST_OPUS_VERSION}.tar.gz"
OPUS_UNPACK_DIR="opus-${LATEST_OPUS_VERSION}" # Primary unpack dir name

download $OPUS_PRIMARY_URL "opus.tar.gz"
if [ $? -ne 0 ]; then
    echo "Download from Xiph.org failed; trying GitLab mirror"
    download $OPUS_GITLAB_URL "opus.tar.gz"
    checkStatus $? "Download from GitLab mirror failed"
    # If GitLab download is used, the unpack dir might be opus-vX.Y.Z
    # However, the script uses a glob `cd opus*$VERSION/` later.
    # For consistency, we'll assume the primary name for the dir.
    # If GitLab tarball unpacks to opus-v<version>, the glob should still work.
fi

# unpack
tar -zxf "opus.tar.gz"
checkStatus $? "unpack failed"
# Use the specific directory name based on the fetched version for robustness
cd "$OPUS_UNPACK_DIR/"
checkStatus $? "change directory failed into $OPUS_UNPACK_DIR (tried, might fallback to glob if this fails)" || cd opus*${LATEST_OPUS_VERSION}/
checkStatus $? "change directory failed"


# check for pre-generated configure file
if [ -f "configure" ]; then
    echo "use existing configure file"
else
    ./autogen.sh
    checkStatus $? "autogen failed"
fi

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
