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
VERSION=$(cat "$SCRIPT_DIR/../version/vvenc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "vvenc"
checkStatus $? "create directory failed"
cd "vvenc/"
checkStatus $? "change directory failed"

# download source
download https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v$VERSION.tar.gz "vvenc.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "vvenc.tar.gz"
checkStatus $? "unpack failed"

# generate pgo profile
mkdir "pgogen"
checkStatus $? "create directory failed"
cd "pgogen/"
checkStatus $? "change directory failed"

cmake -S ../vvenc-$VERSION -B build/release-static -G 'Ninja' -DCMAKE_C_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_CXX_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_INSTALL_PREFIX=$(pwd) -DCMAKE_BUILD_TYPE=Release
checkStatus $? "configuration pgogen failed"

cmake --build build/release-static -j $CPUS
checkStatus $? "build pgogen failed"

cmake --build build/release-static --target install
checkStatus $? "pgogen installation failed"

echo generating profiles
xz -dc $SCRIPT_DIR/../sample/stefan_sif.y4m.xz | bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o ../stefan_sif.266
# if it's way too slow for you, comment out the three lines below
xz -dc $SCRIPT_DIR/../sample/taikotemoto.y4m.xz | bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o ../taikotemoto.266
xz -dc $SCRIPT_DIR/../sample/720p_bbb.y4m.xz | bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o ../720p_bbb.266
xz -dc $SCRIPT_DIR/../sample/4k_bbb.y4m.xz | bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o ../4k_bbb.266

/usr/bin/llvm-profdata merge *.profraw -o ../default.profdata
echo profile generation completed

cd ../vvenc-$VERSION
make realclean
cd ..

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
cd "build/"
checkStatus $? "change directory failed"
# pgo will change function control flow, which will cause error [-Wno-backend-plugin]
cmake -S ../vvenc-$VERSION -B build/release-static -G 'Ninja' -DCMAKE_C_FLAGS="-Wno-error=backend-plugin -fprofile-use=$(pwd)/../default.profdata" -DCMAKE_CXX_FLAGS="-Wno-error=backend-plugin -fprofile-use=$(pwd)/../default.profdata" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_INSTALL_PREFIX=$TOOL_DIR -DCMAKE_BUILD_TYPE=Release

# build
cmake --build build/release-static -j $CPUS
checkStatus $? "build failed"

# install
cmake --build build/release-static --target install
checkStatus $? "installation failed"
