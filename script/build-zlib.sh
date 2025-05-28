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
mkdir "zlib"
checkStatus $? "create directory failed"
cd "zlib/"
checkStatus $? "change directory failed"

# Get latest zlib version from zlib.net
echo "Fetching latest zlib version from zlib.net..."
# This command looks for href="zlib-X.Y.Z.tar.gz" on the zlib.net homepage, extracts X.Y.Z, sorts, and takes the latest.
# It prioritizes .tar.gz, then .tar.xz.
LATEST_ZLIB_VERSION_TARBALL=$(curl -sL https://www.zlib.net/ | \
    grep -oP 'href="(zlib-[0-9\.]+\.tar\.(gz|xz|bz2))"' | \
    sed -E 's|href="(zlib-[0-9\.]+\.tar\.(gz|xz|bz2))"|\1|' | \
    grep -E '^zlib-[0-9]+\.[0-9]+(\.[0-9]+)*\.tar\.(gz|xz|bz2)$' | \
    sort -V | tail -n 1)

LATEST_ZLIB_VERSION=$(echo "$LATEST_ZLIB_VERSION_TARBALL" | sed -E 's|zlib-([0-9\.]+)\.tar\.(gz|xz|bz2)|\1|')
ZLIB_TARBALL_EXT=$(echo "$LATEST_ZLIB_VERSION_TARBALL" | grep -oP '\.tar\.(gz|xz|bz2)$')

checkStatus $? "Failed to fetch latest zlib version details"
if [ -z "$LATEST_ZLIB_VERSION" ] || [ -z "$ZLIB_TARBALL_EXT" ]; then
    echo "ERROR: Could not determine latest zlib version or extension."
    exit 1
fi
echo "Latest zlib version: $LATEST_ZLIB_VERSION (Tarball: $LATEST_ZLIB_VERSION_TARBALL)"

# download source
ZLIB_UNPACK_DIR="zlib-$LATEST_ZLIB_VERSION"
download https://www.zlib.net/$LATEST_ZLIB_VERSION_TARBALL "zlib$ZLIB_TARBALL_EXT" # Save with correct extension
checkStatus $? "download failed"

# unpacking
if [ "$ZLIB_TARBALL_EXT" = ".tar.xz" ]; then
    tar -xf "zlib$ZLIB_TARBALL_EXT"
elif [ "$ZLIB_TARBALL_EXT" = ".tar.bz2" ]; then
    tar -xjf "zlib$ZLIB_TARBALL_EXT"
else # .tar.gz
    tar -zxf "zlib$ZLIB_TARBALL_EXT"
fi
checkStatus $? "unpacking failed"
cd "$ZLIB_UNPACK_DIR/"
checkStatus $? "change directory failed"

DETECTED_OS="$(uname -o 2> /dev/null)"
echo "detected OS: $DETECTED_OS"
if [ $DETECTED_OS = "Msys" ]; then
	echo "run windows specific build"

	# windows build
	make -j $CPUS -f win32/Makefile.gcc
	checkStatus $? "build failed"

	# install
	make -j $CPUS -f win32/Makefile.gcc install INCLUDE_PATH=$TOOL_DIR/include LIBRARY_PATH=$TOOL_DIR/lib BINARY_PATH=$TOO_DIR/bin
	checkStatus $? "installation failed"
else
	# prepare build
	./configure --prefix="$TOOL_DIR" --static
	checkStatus $? "configuration failed"

	# build
	make -j $CPUS
	checkStatus $? "build failed"

	# install
	make install
	checkStatus $? "installation failed"
fi
