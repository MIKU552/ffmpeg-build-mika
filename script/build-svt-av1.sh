#!/bin/sh

# Copyright 2022 Martin Riedl
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
VERSION=$(cat "$SCRIPT_DIR/../version/svt-av1")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "svt-av1"
checkStatus $? "create directory failed"
cd "svt-av1/"
checkStatus $? "change directory failed"

# download source
download https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v$VERSION/SVT-AV1-v$VERSION.tar.gz "SVT-AV1.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "SVT-AV1.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
# Modify pgo helper for xz samples and command execution
sed -i '36s/.y4m/.y4m.xz/g' SVT-AV1-v$VERSION/Build/pgohelper.cmake
sed -i '43s/\${SvtAv1EncApp} -i \${video} -b "\${BUILD_DIRECTORY}\/\${videoname}.ivf" --preset 2 --film-grain 8 --tune 0/"xz -dc \${video} | \${SvtAv1EncApp} -i - -b \\"\${BUILD_DIRECTORY}\/\${videoname}.ivf\\" --preset 2 --film-grain 8 --tune 0 --lookahead 120"/g' SVT-AV1-v$VERSION/Build/pgohelper.cmake
sed -i '49s/\${ENCODING_COMMAND}/sh -c "\${ENCODING_COMMAND}"/g' SVT-AV1-v$VERSION/Build/pgohelper.cmake
# Remove clang-specific flag injection (if any) - the sed command below targeting lines 280-281 might be wrong or outdated. Check CMakeLists.txt manually if needed.
# sed -i '...' SVT-AV1-$VERSION/CMakeLists.txt # Commented out potential Clang flag injection
checkStatus $? "edit pgohelper.cmake failed"
cd "build/"
checkStatus $? "change directory failed"
# Configure for GCC PGO/LTO - Remove LLVM_PROFDATA
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DSVT_AV1_LTO=ON -DSVT_AV1_PGO=ON -DSVT_AV1_PGO_CUSTOM_VIDEOS="$SCRIPT_DIR/../sample" -DBUILD_SHARED_LIBS=NO ../SVT-AV1-$VERSION
checkStatus $? "configuration failed"

# build
make RunPGO -j $CPUS
checkStatus $? "PGO build failed"

# install
make install
checkStatus $? "installation failed"