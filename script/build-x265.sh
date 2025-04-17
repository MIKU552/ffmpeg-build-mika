#!/bin/bash

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
# Reconstruct LOG_DIR path
LOG_DIR="$(pwd)/log" # Assuming build.sh runs this script from the $WORKING_DIR set in build.sh

# load functions
. $SCRIPT_DIR/functions.sh

# --- Restore version loading, download and unpack ---
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load x265 version failed"
echo "x265 version: $VERSION"

cd "$SOURCE_DIR"
checkStatus $? "change directory to $SOURCE_DIR failed"
mkdir -p "x265"
cd "x265/"
checkStatus $? "change directory to $SOURCE_DIR/x265 failed"

X265_TARBALL="x265_${VERSION}.tar.gz"
X265_SOURCE_SUBDIR="x265_source"

if [ ! -f "$X265_TARBALL" ]; then
    echo "Downloading x265 source (version $VERSION)..."
    download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "$X265_TARBALL"
    checkStatus $? "download of x265 ($VERSION) failed"
else
    echo "Using existing x265 tarball: $X265_TARBALL"
fi

if [ -d "$X265_SOURCE_SUBDIR" ]; then
    echo "Cleaning existing x265 source unpack directory: $X265_SOURCE_SUBDIR"
    rm -rf "$X265_SOURCE_SUBDIR"
fi
mkdir "$X265_SOURCE_SUBDIR"
checkStatus $? "create directory $X265_SOURCE_SUBDIR failed"
echo "Unpacking $X265_TARBALL..."
tar -zxf "$X265_TARBALL" -C "$X265_SOURCE_SUBDIR" --strip-components=1
checkStatus $? "unpack failed"

echo "DEBUG: Contents of $X265_SOURCE_SUBDIR after unpack:"
ls -lA "$X265_SOURCE_SUBDIR"
echo "DEBUG: Contents of $X265_SOURCE_SUBDIR/source (if exists):"
ls -lA "$X265_SOURCE_SUBDIR/source" 2>/dev/null || echo "  (source subdir not found)"
echo "-------------------------------------------"

cd "$X265_SOURCE_SUBDIR/"
checkStatus $? "change directory into $X265_SOURCE_SUBDIR failed"
SOURCE_ROOT_PWD=$(pwd)

echo "Patching x265 CMakeLists.txt to include CheckCompilerFlag modules..."
X265_MAIN_CMAKE_PATH="source/CMakeLists.txt"
if [ -f "$X265_MAIN_CMAKE_PATH" ]; then
    awk '
    /project *\(.*\)/ { print; print "include(CheckCCompilerFlag)"; print "include(CheckCXXCompilerFlag)"; next }
    { print }
    ' "$X265_MAIN_CMAKE_PATH" > "$X265_MAIN_CMAKE_PATH.tmp" && mv "$X265_MAIN_CMAKE_PATH.tmp" "$X265_MAIN_CMAKE_PATH"
    checkStatus $? "Patching CMakeLists.txt failed"
    echo "CMakeLists.txt patched."
else
    echo "Warning: $X265_MAIN_CMAKE_PATH not found, skipping patch."
fi

# Create build directories OUTSIDE source tree, relative to SOURCE ROOT PWD
BUILD_DIR_BASE="../build"
mkdir -p "${BUILD_DIR_BASE}/8bitgen"
checkStatus $? "create 8bitgen directory failed"
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    mkdir -p "${BUILD_DIR_BASE}/10bitgen"
    checkStatus $? "create 10bitgen directory failed"
    mkdir -p "${BUILD_DIR_BASE}/12bitgen"
    checkStatus $? "create 12bitgen directory failed"
    # Also create final build dirs placeholders now (they will be cleaned later)
    mkdir -p "${BUILD_DIR_BASE}/8bit"
    mkdir -p "${BUILD_DIR_BASE}/10bit"
    mkdir -p "${BUILD_DIR_BASE}/12bit"
else
    mkdir -p "${BUILD_DIR_BASE}/8bit" # For single bit final build
fi

echo compiling 8bit profile generator
cd "${BUILD_DIR_BASE}/8bitgen"
checkStatus $? "change directory to 8bitgen failed"
rm -f CMakeCache.txt
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO ../../x265_source/source
checkStatus $? "8bitgen configuration failed"
make -j $CPUS
checkStatus $? "build 8bitgen failed"
cd "$SOURCE_ROOT_PWD"
checkStatus $? "change directory back to x265_source failed"

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    echo compiling 10bit profile generator
    cd "${BUILD_DIR_BASE}/10bitgen"
    checkStatus $? "change directory to 10bitgen failed"
    rm -f CMakeCache.txt
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON ../../x265_source/source
    checkStatus $? "10bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 10bitgen failed"
    cd "$SOURCE_ROOT_PWD"
    checkStatus $? "change directory back to x265_source failed"

    echo compiling 12bit profile generator
    cd "${BUILD_DIR_BASE}/12bitgen"
    checkStatus $? "change directory to 12bitgen failed"
    rm -f CMakeCache.txt
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON -DMAIN12=ON ../../x265_source/source
    checkStatus $? "12bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 12bitgen failed"
    cd "$SOURCE_ROOT_PWD"
    checkStatus $? "change directory back to x265_source failed"
fi

echo generating profiles simutaneously
SAMPLE_DIR_REL_SCRIPT="$SCRIPT_DIR/../sample"
# Run PGO training using executables from build directories, remove --pmode
(cd "${BUILD_DIR_BASE}/8bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 8bit &

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
(cd "${BUILD_DIR_BASE}/10bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 10bit &
(cd "${BUILD_DIR_BASE}/12bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 12bit &
fi

wait
echo profile generating completed


# --- Build Final Libraries ---
# Clean previous final build directories if they exist
echo "Cleaning final build directories..."
rm -rf "${BUILD_DIR_BASE}/8bit" "${BUILD_DIR_BASE}/10bit" "${BUILD_DIR_BASE}/12bit"

# --- FIX: Recreate final build directories ---
echo "Recreating final build directories..."
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    mkdir -p "${BUILD_DIR_BASE}/8bit"
    checkStatus $? "create final 8bit directory failed"
    mkdir -p "${BUILD_DIR_BASE}/10bit"
    checkStatus $? "create final 10bit directory failed"
    mkdir -p "${BUILD_DIR_BASE}/12bit"
    checkStatus $? "create final 12bit directory failed"
else
     mkdir -p "${BUILD_DIR_BASE}/8bit" # For single bit final build
     checkStatus $? "create final 8bit directory failed"
fi
# --- End FIX ---

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    # --- 10 bit final build ---
    echo "start final 10bit build"
    cd "${BUILD_DIR_BASE}/10bit/" # <-- This is line 171 (approx) where error occurred
    checkStatus $? "change directory to final 10bit failed"
    # Point to source dir (../../x265_source/source)
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON ../../x265_source/source
    checkStatus $? "configuration final 10 bit failed"
    make -j $CPUS
    checkStatus $? "build final 10 bit failed"
    cd "$SOURCE_ROOT_PWD" # Go back to source root
    checkStatus $? "change directory back to x265_source failed"

    # --- 12 bit final build ---
    echo "start final 12bit build"
    cd "${BUILD_DIR_BASE}/12bit/"
    checkStatus $? "change directory to final 12bit failed"
    # Point to source dir (../../x265_source/source)
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON -DMAIN12=ON ../../x265_source/source
    checkStatus $? "configuration final 12 bit failed"
    make -j $CPUS
    checkStatus $? "build final 12 bit failed"
    cd "$SOURCE_ROOT_PWD" # Go back to source root
    checkStatus $? "change directory back to x265_source failed"

    # --- 8 bit final build (linking others) ---
    echo "start final 8bit build"
    cd "${BUILD_DIR_BASE}/8bit"
    checkStatus $? "change directory to final 8bit failed"

    # Create symlinks relative to the current directory pointing to other build dirs
    ln -sf ../10bit/libx265.a libx265_10bit.a
    checkStatus $? "symlink creation of 10 bit library failed"
    ln -sf ../12bit/libx265.a libx265_12bit.a
    checkStatus $? "symlink creation of 12 bit library failed"
    # Configure 8bit using PGO-use flags and linking extras
    # Point to source dir (../../x265_source/source)
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
        -DEXTRA_LIB="x265_10bit;x265_12bit" -DEXTRA_LINK_FLAGS="-L$(pwd)" -DLINKED_10BIT=ON -DLINKED_12BIT=ON ../../x265_source/source
    checkStatus $? "configuration final 8 bit failed"
    make -j $CPUS
    checkStatus $? "build final 8 bit failed"

    # install (install from 8bit directory as it contains the final linked library)
    make install
    checkStatus $? "installation failed"
    cd "$SOURCE_ROOT_PWD" # Go back to source root
    checkStatus $? "change directory back to x265_source failed"

else
    # Single bit depth build (Assume 8bit)
    echo "start final single-bit build"
    cd "${BUILD_DIR_BASE}/8bit/"
    checkStatus $? "change directory to final 8bit failed"
    # Point to source dir (../../x265_source/source)
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF ../../x265_source/source
    checkStatus $? "configuration failed"
    make -j $CPUS
    checkStatus $? "build failed"
    make install
    checkStatus $? "installation failed"
    cd "$SOURCE_ROOT_PWD" # Go back to source root
    checkStatus $? "change directory back to x265_source failed"
fi

# post-installation fix for pkgconfig (remains the same)
echo "Applying post-installation fix to x265.pc"
if [ -f "$TOOL_DIR/lib/pkgconfig/x265.pc" ]; then
    sed -i.original -e 's/lx265/lx265 -lpthread/g' "$TOOL_DIR/lib/pkgconfig/x265.pc"
    checkStatus $? "modify pkg-config failed"
else
    echo "Warning: $TOOL_DIR/lib/pkgconfig/x265.pc not found, skipping post-install fix."
fi


# Go back to the directory build-x265.sh was called from ($SOURCE_DIR/x265)
cd ..
checkStatus $? "Failed to cd back to $SOURCE_DIR/x265 directory"