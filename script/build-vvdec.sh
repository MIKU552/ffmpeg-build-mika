#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
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
VERSION=$(cat "$SCRIPT_DIR/../version/vvdec")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "vvdec"
checkStatus $? "create directory failed"
cd "vvdec/"
checkStatus $? "change directory failed"

# download source
download https://gh-proxy.com/https://github.com/fraunhoferhhi/vvdec/archive/$VERSION.tar.gz "vvdec.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "vvdec.tar.gz"
checkStatus $? "unpack failed"

# generate pgo profile
mkdir "pgogen"
checkStatus $? "create directory failed"
cd "pgogen/"
checkStatus $? "change directory failed"

cmake -S ../vvdec-$VERSION -B build/release-static -G 'Ninja' -DVVDEC_INSTALL_VVDECAPP=ON -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_INSTALL_PREFIX=$(pwd) -DCMAKE_BUILD_TYPE=Release
checkStatus $? "configuration pgogen failed"

cmake --build build/release-static -j $CPUS
checkStatus $? "build pgogen failed"

cmake --build build/release-static --target install
checkStatus $? "pgogen installation failed"

echo generating profiles
bin/vvdecapp -b ../../vvenc/stefan_sif.266 -o /dev/null
bin/vvdecapp -b ../../vvenc/taikotemoto.266 -o /dev/null
bin/vvdecapp -b ../../vvenc/720p_bbb.266 -o /dev/null
bin/vvdecapp -b ../../vvenc/4k_bbb.266 -o /dev/null

# Profile merging usually not needed for GCC >= 9
# If needed: gcov-tool merge ...
echo profile generation completed

cd ../vvdec-$VERSION
make realclean # vvdec uses make for cleaning
cd ..

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
cd "build/"
checkStatus $? "change directory failed"
cmake -S ../vvdec-$VERSION -B build/release-static -G 'Ninja' -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_INSTALL_PREFIX=$TOOL_DIR -DCMAKE_BUILD_TYPE=Release

# build
cmake --build build/release-static -j $CPUS
checkStatus $? "build failed"

# install
cmake --build build/release-static --target install
checkStatus $? "installation failed"