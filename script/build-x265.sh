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
SKIP_X265_MULTIBIT=$5

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "x265"
checkStatus $? "create directory failed"
cd "x265/"
checkStatus $? "change directory failed"

# download source
download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "x265.tar.gz"
checkStatus $? "download of x265 failed"

# unpack
mkdir "x265"
checkStatus $? "create directory failed"
tar -zxf "x265.tar.gz" -C x265 --strip-components=1
checkStatus $? "unpack failed"
cd "x265/"
checkStatus $? "change directory failed"

# generate pgo profile
sed -i '19s/.*/cmake_policy(SET CMP0069 NEW)/' source/CMakeLists.txt
sed -i '20s/.*/project (x265)/' source/CMakeLists.txt
sed -i '1a\
cmake_minimum_required(VERSION 2.8.8)
' source/CMakeLists.txt
mkdir 8bitgen
checkStatus $? "create directory failed"
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
mkdir 10bitgen
checkStatus $? "create directory failed"
mkdir 12bitgen
checkStatus $? "create directory failed"
fi

echo compiling 8bit profile generator
cd 8bitgen
checkStatus $? "change directory failed"
cmake -DCMAKE_C_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_CXX_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DFPROFILE_GENERATE=ON ../source
checkStatus $? "8bitgen configuration failed"
make -j 16
checkStatus $? "build 8bitgen failed"
cd ..
checkStatus $? "change directory failed"

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
echo compiling 10bit profile generator
cd 10bitgen
checkStatus $? "change directory failed"
cmake -DCMAKE_C_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_CXX_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON -DFPROFILE_GENERATE=ON ../source
checkStatus $? "10bitgen configuration failed"
make -j 16
checkStatus $? "build 10bitgen failed"
cd ..
checkStatus $? "change directory failed"

echo compiling 12bit profile generator
cd 12bitgen
checkStatus $? "change directory failed"
cmake -DCMAKE_C_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_CXX_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON -DMAIN12=ON -DFPROFILE_GENERATE=ON ../source
checkStatus $? "12bitgen configuration failed"
make -j 16
checkStatus $? "build 12bitgen failed"
cd ..
checkStatus $? "change directory failed"
fi

echo generating profiles simutaneously
$(cd 8bitgen && xz -dc $SCRIPT_DIR/../sample/stefan_sif.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/taikotemoto.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/720p_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/4k_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26) && echo 8bit &

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
$(cd 10bitgen && xz -dc $SCRIPT_DIR/../sample/stefan_sif.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/taikotemoto.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/720p_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/4k_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26) && echo 10bit &

$(cd 12bitgen && xz -dc $SCRIPT_DIR/../sample/stefan_sif.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/taikotemoto.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/720p_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26 && xz -dc $SCRIPT_DIR/../sample/4k_bbb.y4m.xz | ./x265 --y4m --input - -o /dev/null --preset veryslow --pmode --no-info --crf 26) && echo 12bit &
fi

wait
llvm-profdata merge *bitgen/*.profraw -o default.profdata
echo profile generating completed

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    # prepare build 10 bit
    echo "start with 10bit build"
    mkdir 10bit
    checkStatus $? "create directory failed"
    cd 10bit/
    checkStatus $? "change directory failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_CXX_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON ../source
    checkStatus $? "configuration 10 bit failed"

    # build 10 bit
    make -j $CPUS
    checkStatus $? "build 10 bit failed"
    cd ..
    checkStatus $? "change directory failed"

    # prepare build 12 bit
    echo "start with 12bit build"
    mkdir 12bit
    checkStatus $? "create directory failed"
    cd 12bit/
    checkStatus $? "change directory failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_CXX_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON -DMAIN12=ON ../source
    checkStatus $? "configuration 12 bit failed"

    # build 12 bit
    make -j $CPUS
    checkStatus $? "build 12 bit failed"
    cd ..
    checkStatus $? "change directory failed"

    # prepare build 8 bit
    echo "start with 8bit build"
    ln -s 10bit/libx265.a libx265_10bit.a
    checkStatus $? "symlink creation of 10 bit library failed"
    ln -s 12bit/libx265.a libx265_12bit.a
    checkStatus $? "symlink creation of 12 bit library failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_CXX_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
        -DEXTRA_LINK_FLAGS=-L. -DEXTRA_LIB="x265_10bit.a;x265_12bit.a" -DLINKED_10BIT=ON -DLINKED_12BIT=ON source
    checkStatus $? "configuration 8 bit failed"

    # build 8 bit
    make -j $CPUS
    checkStatus $? "build 8 bit failed"

    # merge libraries
    mv libx265.a libx265_8bit.a
    checkStatus $? "move 8 bit library failed"
    if [ "$(uname)" = "Linux" ]; then
    ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_8bit.a
ADDLIB libx265_10bit.a
ADDLIB libx265_12bit.a
SAVE
END
EOF
    else
        libtool -static -o libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
    fi
    checkStatus $? "multi-bit library creation failed"
else
    # prepare build
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_CXX_FLAGS="-fprofile-use=$SOURCE_DIR/x265/x265/default.profdata" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF source
    checkStatus $? "configuration failed"

    # build
    make -j $CPUS
    checkStatus $? "build failed"
fi

# install
make install
checkStatus $? "installation failed"

# post-installation
# modify pkg-config file for usage with ffmpeg (it seems that the flag for threads is missing)
# --> https://bitbucket.org/multicoreware/x265_git/issues/371/x265-not-found-using-pkg-config
sed -i.original -e 's/lx265/lx265 -lpthread/g' $TOOL_DIR/lib/pkgconfig/x265.pc
