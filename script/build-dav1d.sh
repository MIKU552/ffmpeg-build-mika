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

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/dav1d")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "dav1d"
checkStatus $? "create directory failed"
cd "dav1d/"
checkStatus $? "change directory failed"

# download source
download https://code.videolan.org/videolan/dav1d/-/archive/$VERSION/dav1d-$VERSION.tar.gz "dav1d.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "dav1d.tar.gz"
checkStatus $? "unpack failed"

# prepare python3 virtual environment
python3 -m virtualenv .venv
if [ $? -ne 0 ]; then
    echo "python create virtual environment failed"

    # check, if meson is natively available
    MESON_VERSION=$(meson -v 2> /dev/null)
    checkStatus $? "meson was also not found: please install python correctly with virtualenv"
    echo "using meson $MESON_VERSION"
else
    . .venv/bin/activate
    checkStatus $? "python activate virtual environment failed"
    pip install meson
    checkStatus $? "python meson installation failed"
fi

# prepare build
cd "dav1d-$VERSION/"
checkStatus $? "change directory failed"
meson build --prefix "$TOOL_DIR" --libdir=lib --default-library=static
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"
