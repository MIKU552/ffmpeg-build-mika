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
mkdir "lame"
checkStatus $? "create directory failed"
cd "lame/"
checkStatus $? "change directory failed"

# Get latest lame version from SourceForge
echo "Fetching latest lame version from SourceForge..."
# This command looks for directory links like "/projects/lame/files/lame/3.100/"
# then extracts "3.100", sorts them, and takes the last one.
LATEST_LAME_VERSION=$(curl -sL https://sourceforge.net/projects/lame/files/lame/ | \
    grep -oP 'href="/projects/lame/files/lame/([0-9\.]+)/"' | \
    sed -E 's|href="/projects/lame/files/lame/([0-9\.]+)/"|\1|' | \
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | \
    sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest lame version"
echo "Latest lame version: $LATEST_LAME_VERSION"

# download source
LAME_TARBALL="lame-$LATEST_LAME_VERSION.tar.gz"
LAME_UNPACK_DIR="lame-$LATEST_LAME_VERSION"
# SourceForge download URLs can be tricky; this is a common pattern.
# Using a more direct link, if possible, by constructing from the version.
download https://downloads.sourceforge.net/project/lame/lame/$LATEST_LAME_VERSION/$LAME_TARBALL "$LAME_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$LAME_TARBALL"
checkStatus $? "unpack lame failed"
cd "$LAME_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
