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
mkdir "aom"
checkStatus $? "create directory failed"
cd "aom/"
checkStatus $? "change directory failed"

# Get latest AOM version from GitHub API
echo "Fetching latest AOM version from GitHub..."
LATEST_AOM_TAG=$(curl -s https://api.github.com/repos/AOMediaCodec/libaom/releases/latest | jq -r '.tag_name')
checkStatus $? "Failed to fetch latest AOM version tag"
# Remove 'v' prefix if present (e.g. v3.6.0 -> 3.6.0)
LATEST_AOM_VERSION=$(echo "$LATEST_AOM_TAG" | sed 's/^v//')
echo "Latest AOM version: $LATEST_AOM_VERSION"

# download source
AOM_TARBALL="libaom-$LATEST_AOM_VERSION.tar.gz"
AOM_UNPACK_DIR="libaom-$LATEST_AOM_VERSION"
download https://storage.googleapis.com/aom-releases/$AOM_TARBALL "$AOM_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$AOM_TARBALL"
checkStatus $? "unpack failed"

# prepare build
mkdir aom_build
checkStatus $? "create build directory failed"
cd aom_build
checkStatus $? "change build directory failed"
# Enable LTO for AOM
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_TESTS=0 -DENABLE_LTO=1 ../$AOM_UNPACK_DIR/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"