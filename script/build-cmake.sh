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

# versions
VERSION_MINOR="3.31"
VERSION_PATCH="3.31.1"

# detect existing installation of cmake
CURRENT_VERSION=$(cmake --version | grep -m 1 "" |  sed -r 's/.*([0-9]+\.[0-9]+\.[0-9]+)/\1/')
echo "detected installed version of cmake: $CURRENT_VERSION"
if [ "$CURRENT_VERSION" = "$VERSION_PATCH" ]; then
    echo "cmake already in current version available"
    exit 0
fi

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "cmake"
checkStatus $? "create directory failed"
cd "cmake/"
checkStatus $? "change directory failed"

# download pre-build cmake
CMAKE_OS=""
CMAKE_ARCH=""
CURRENT_OS="$(uname)"
CURRENT_ARCH="$(uname -m)"
if [ "$CURRENT_OS" = "Darwin" ]; then
    echo "darwin detected"
    CMAKE_OS="macos"
    CMAKE_ARCH="universal"
elif [ "$CURRENT_OS" = "Linux" ] && [ "$CURRENT_ARCH" = "x86_64" ]; then
    echo "linux x86_64 detected"
    CMAKE_OS="linux"
    CMAKE_ARCH="x86_64"
elif [ "$CURRENT_OS" = "Linux" ] && [ "$CURRENT_ARCH" = "aarch64" ]; then
    echo "linux aarch64 detected"
    CMAKE_OS="linux"
    CMAKE_ARCH="aarch64"
else
    echo "no supported os detected: ${CURRENT_OS} ${CURRENT_ARCH}"
fi
download https://github.com/Kitware/CMake/releases/download/v${VERSION_PATCH}/cmake-${VERSION_PATCH}-${CMAKE_OS}-${CMAKE_ARCH}.tar.gz "cmake-release.tar.gz"
if [ $? -ne 0 ]; then
    echo "download of cmake release failed; continue with local build"
else
    # unpack cmake-release
    tar -zxf "cmake-release.tar.gz"
    checkStatus $? "unpack of release failed"
    cd "cmake-${VERSION_PATCH}-${CMAKE_OS}-${CMAKE_ARCH}"
    checkStatus $? "change release directory failed"
    if [ "$CURRENT_OS" = "Darwin" ]; then
        cd "CMake.app/Contents"
        checkStatus $? "change app directory failed"
    fi

    # copy required files
    cp bin/* "$TOOL_DIR/bin"
    checkStatus $? "copy cmake bin failed"
    cp -r share/* "$TOOL_DIR/share"
    checkStatus $? "copy cmake share failed"
    exit 0
fi

# download source
download https://cmake.org/files/v$VERSION_MINOR/cmake-$VERSION_PATCH.tar.gz "cmake.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "cmake.tar.gz"
checkStatus $? "unpack failed"
cd "cmake-$VERSION_PATCH/"
checkStatus $? "change directory failed"

# prepare build
export OPENSSL_ROOT_DIR="$TOOL_DIR"
./configure --prefix="$TOOL_DIR" --parallel="$CPUS"
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
