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
# Reconstruct LOG_DIR path using PWD which is the $WORKING_DIR from build.sh
LOG_DIR="$(pwd)/log"

# load functions
. $SCRIPT_DIR/functions.sh

# --- Restore version loading, download and unpack ---
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load x265 version failed"
echo "x265 version: $VERSION"

# Define base directory for this library's source and build
X265_BASE_DIR="$SOURCE_DIR/x265" # e.g., .../source/x265
mkdir -p "$X265_BASE_DIR"
checkStatus $? "create directory $X265_BASE_DIR failed"
cd "$X265_BASE_DIR"
checkStatus $? "change directory to $X265_BASE_DIR failed"

X265_TARBALL="x265_${VERSION}.tar.gz"
X265_SOURCE_SUBDIR="x265_source" # Source code unpack location
X265_BUILD_DIR="build"         # Build directory parent, sibling to source subdir

# --- Download ---
if [ ! -f "$X265_TARBALL" ]; then
    echo "Downloading x265 source (version $VERSION)..."
    download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "$X265_TARBALL"
    checkStatus $? "download of x265 ($VERSION) failed"
else
    echo "Using existing x265 tarball: $X265_TARBALL"
fi

# --- Unpack ---
if [ -d "$X265_SOURCE_SUBDIR" ]; then
    echo "Cleaning existing x265 source unpack directory: $X265_SOURCE_SUBDIR"
    rm -rf "$X265_SOURCE_SUBDIR"
fi
mkdir "$X265_SOURCE_SUBDIR"
checkStatus $? "create directory $X265_SOURCE_SUBDIR failed"
echo "Unpacking $X265_TARBALL..."
tar -zxf "$X265_TARBALL" -C "$X265_SOURCE_SUBDIR" --strip-components=1
checkStatus $? "unpack failed"

# Define ABSOLUTE paths AFTER creating/cleaning dirs
X265_SOURCE_ABS_PATH=$(pwd)/$X265_SOURCE_SUBDIR
X265_BUILD_ABS_PATH=$(pwd)/$X265_BUILD_DIR

echo "DEBUG: Absolute source path: $X265_SOURCE_ABS_PATH"
echo "DEBUG: Absolute build path base: $X265_BUILD_ABS_PATH"

# --- Patch CMakeLists.txt ---
cd "$X265_SOURCE_ABS_PATH" # Go into source dir to patch
checkStatus $? "change directory into $X265_SOURCE_ABS_PATH failed"

echo "Patching x265 CMakeLists.txt to include CheckCompilerFlag modules..."
X265_MAIN_CMAKE_PATH="source/CMakeLists.txt" # Path relative to x265_source root
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
cd .. # Go back to base dir (source/x265) for consistency
checkStatus $? "cd back to $X265_BASE_DIR failed"


# --- Create Build Directories using Absolute Path ---
mkdir -p "${X265_BUILD_ABS_PATH}/8bitgen"
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    mkdir -p "${X265_BUILD_ABS_PATH}/10bitgen"
    mkdir -p "${X265_BUILD_ABS_PATH}/12bitgen"
    mkdir -p "${X265_BUILD_ABS_PATH}/8bit"
    mkdir -p "${X265_BUILD_ABS_PATH}/10bit"
    mkdir -p "${X265_BUILD_ABS_PATH}/12bit"
else
    mkdir -p "${X265_BUILD_ABS_PATH}/8bit"
fi
checkStatus $? "create build directories failed"


# --- PGO Generate Phase ---
echo compiling 8bit profile generator
cd "${X265_BUILD_ABS_PATH}/8bitgen" # Use absolute path
checkStatus $? "change directory to 8bitgen failed"
rm -f CMakeCache.txt
cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO "$X265_SOURCE_ABS_PATH/source"
checkStatus $? "8bitgen configuration failed"
make -j $CPUS
checkStatus $? "build 8bitgen failed"

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    echo compiling 10bit profile generator
    cd "${X265_BUILD_ABS_PATH}/10bitgen" # Use absolute path
    checkStatus $? "change directory to 10bitgen failed"
    rm -f CMakeCache.txt
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "10bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 10bitgen failed"

    echo compiling 12bit profile generator
    cd "${X265_BUILD_ABS_PATH}/12bitgen" # Use absolute path
    checkStatus $? "change directory to 12bitgen failed"
    rm -f CMakeCache.txt
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-generate" -DCMAKE_CXX_FLAGS="-fprofile-generate" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DHIGH_BIT_DEPTH=ON -DMAIN12=ON "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "12bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 12bitgen failed"
fi

# Go back to a known base directory before PGO training which uses relative paths?
cd "$X265_BASE_DIR" # Go back to source/x265 before PGO training
checkStatus $? "Failed cd back to X265_BASE_DIR before PGO training"

echo generating profiles simutaneously
SAMPLE_DIR_REL_SCRIPT="$SCRIPT_DIR/../sample"
# Run PGO training using executables from ABSOLUTE build directories
(cd "${X265_BUILD_ABS_PATH}/8bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 8bit &
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
(cd "${X265_BUILD_ABS_PATH}/10bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 10bit &
(cd "${X265_BUILD_ABS_PATH}/12bitgen" && xz -dc "$SAMPLE_DIR_REL_SCRIPT/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SAMPLE_DIR_REL_SCRIPT/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26) && echo 12bit &
fi
wait
echo profile generating completed


# --- Build Final Libraries ---
# Clean final build directories first (using absolute path)
echo "Cleaning final build directories..."
rm -rf "${X265_BUILD_ABS_PATH}/8bit" "${X265_BUILD_ABS_PATH}/10bit" "${X265_BUILD_ABS_PATH}/12bit"
# Recreate them
mkdir -p "${X265_BUILD_ABS_PATH}/8bit"
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    mkdir -p "${X265_BUILD_ABS_PATH}/10bit"
    mkdir -p "${X265_BUILD_ABS_PATH}/12bit"
fi
checkStatus $? "Recreate final build directories failed"


if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    # --- Build final 10 bit ---
    echo "start final 10bit build"
    cd "${X265_BUILD_ABS_PATH}/10bit/" # Use absolute path
    checkStatus $? "change directory to final 10bit failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "configuration final 10 bit failed"
    make -j $CPUS # <-- Use default 'all' target
    checkStatus $? "build final 10 bit library failed"
    # No need to cd back if using absolute paths

    # --- Build final 12 bit ---
    echo "start final 12bit build"
    cd "${X265_BUILD_ABS_PATH}/12bit/" # Use absolute path
    checkStatus $? "change directory to final 12bit failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON -DMAIN12=ON "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "configuration final 12 bit failed"
    make -j $CPUS # <-- Use default 'all' target
    checkStatus $? "build final 12 bit library failed"
    # No need to cd back
fi

# --- Build final 8 bit ---
echo "start final 8bit build"
cd "${X265_BUILD_ABS_PATH}/8bit" # Use absolute path
checkStatus $? "change directory to final 8bit failed"
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    # Configure pure 8bit library
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "configuration final 8 bit (multi prep) failed"
else
    # Configure pure 8bit library
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DCMAKE_C_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_CXX_FLAGS="-fprofile-use -Wno-missing-profile" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DENABLE_SHARED=NO -DENABLE_CLI=OFF "$X265_SOURCE_ABS_PATH/source"
    checkStatus $? "configuration final 8 bit (single) failed"
fi
make -j $CPUS # <-- Use default 'all' target
checkStatus $? "build final 8 bit library failed"
# --- Install headers and pkgconfig from 8bit build ---
echo "Installing headers and pkgconfig file from 8bit build..."
make install # This will install headers, .pc file, and potentially overwrite libx265.a
checkStatus $? "installation of headers/pc failed"
# No need to cd back


# --- Manual Library Merging (if needed) ---
if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    echo "Manually merging x265 libraries..."
    mkdir -p "$TOOL_DIR/lib"
    # Copy individual libraries from their build dirs to tool dir with specific names
    cp "${X265_BUILD_ABS_PATH}/8bit/libx265.a" "$TOOL_DIR/lib/libx265_8bit.a"
    checkStatus $? "Copy 8bit lib failed"
    cp "${X265_BUILD_ABS_PATH}/10bit/libx265.a" "$TOOL_DIR/lib/libx265_10bit.a"
    checkStatus $? "Copy 10bit lib failed"
    cp "${X265_BUILD_ABS_PATH}/12bit/libx265.a" "$TOOL_DIR/lib/libx265_12bit.a"
    checkStatus $? "Copy 12bit lib failed"

    # Change to tool lib directory and merge
    cd "$TOOL_DIR/lib"
    checkStatus $? "Failed to cd to $TOOL_DIR/lib"

    echo "Running ar -M to merge libraries..."
    rm -f libx265.a # Remove potentially incomplete library from 'make install'
    # Use ar -M script
    ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_8bit.a
ADDLIB libx265_10bit.a
ADDLIB libx265_12bit.a
SAVE
END
EOF
    checkStatus $? "multi-bit library creation (ar -M) failed"
    # Clean up individual bit depth libraries? Optional.
    # rm libx265_8bit.a libx265_10bit.a libx265_12bit.a
    cd "$X265_BASE_DIR" # Go back to source/x265 base dir
    checkStatus $? "change directory back to x265 base from tool/lib failed"

else
    # For single bit depth, ensure the library from 'make install' is correct
    echo "Ensuring single-bit library is installed..."
    if [ ! -f "$TOOL_DIR/lib/libx265.a" ]; then
        echo "ERROR: libx265.a not found in tool directory after single-bit install!"
        exit 1
    fi
    cd "$X265_BASE_DIR" # Go back to source/x265 base dir
    checkStatus $? "change directory back to x265 base failed"
fi


# post-installation fix for pkgconfig
echo "Applying post-installation fix to x265.pc"
if [ -f "$TOOL_DIR/lib/pkgconfig/x265.pc" ]; then
    sed -i.original -e 's/lx265/lx265 -lpthread/g' "$TOOL_DIR/lib/pkgconfig/x265.pc"
    checkStatus $? "modify pkg-config failed"
else
    echo "Warning: $TOOL_DIR/lib/pkgconfig/x265.pc not found, skipping post-install fix."
fi

# Script finishes, return to the directory build-x265.sh was called from implicitly
# (build.sh calls this script from $WORKING_DIR, script ends in $X265_BASE_DIR = $SOURCE_DIR/x265)