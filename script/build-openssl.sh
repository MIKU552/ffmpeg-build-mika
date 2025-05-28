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
mkdir "openssl"
checkStatus $? "create directory failed"
cd "openssl/"
checkStatus $? "change directory failed"

# Get latest openssl version from GitHub API
echo "Fetching latest openssl version from GitHub..."
LATEST_OPENSSL_TAG=$(get_latest_github_release_tag "openssl/openssl")
checkStatus $? "Failed to fetch latest openssl tag from GitHub"
echo "Latest openssl tag: $LATEST_OPENSSL_TAG" # e.g., openssl-3.2.0

# Extract version from tag (e.g., "openssl-3.2.0" -> "3.2.0")
LATEST_OPENSSL_VERSION=$(echo "$LATEST_OPENSSL_TAG" | sed 's/^openssl-//')
checkStatus $? "Failed to parse openssl version from tag (sed)"
echo "Latest openssl version: $LATEST_OPENSSL_VERSION"

# download source
# The download URL uses the full tag, and the tarball also includes the version.
OPENSSL_DOWNLOAD_URL="https://github.com/openssl/openssl/releases/download/${LATEST_OPENSSL_TAG}/openssl-${LATEST_OPENSSL_VERSION}.tar.gz"
OPENSSL_UNPACK_DIR="openssl-${LATEST_OPENSSL_VERSION}"

download "$OPENSSL_DOWNLOAD_URL" "openssl.tar.gz" # Use a fixed downloaded tarball name
checkStatus $? "download failed"

# unpack
tar -zxf "openssl.tar.gz"
checkStatus $? "unpack failed"
cd "$OPENSSL_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
# use custom lib path, because for any reason on linux amd64 installs otherwise in lib64 instead
./config --prefix="$TOOL_DIR" --openssldir="$TOOL_DIR/openssl" --libdir="$TOOL_DIR/lib" no-shared
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
## install without documentation
make install_sw
checkStatus $? "installation failed (install_sw)"
make install_ssldirs
checkStatus $? "installation failed (install_ssldirs)"
