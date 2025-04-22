#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
# Merged for Linux & macOS compatibility

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

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "x265" # Use -p
cd "x265/"
checkStatus $? "change directory failed"

# download source
X265_TARBALL="x265-$VERSION.tar.gz" # Consistent name
X265_UNPACK_DIR="x265-src" # Consistent name
download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "$X265_TARBALL"
checkStatus $? "download of x265 failed"

# unpack
mkdir -p "$X265_UNPACK_DIR"
checkStatus $? "create directory failed"
tar -zxf "$X265_TARBALL" -C "$X265_UNPACK_DIR" --strip-components=1
checkStatus $? "unpack failed"
rm "$X265_TARBALL" # Clean up
cd "$X265_UNPACK_DIR/"
checkStatus $? "change directory failed"


# --- Apply CMake Patches ---
X265_MAIN_CMAKE_PATH="source/CMakeLists.txt"
echo "Patching $X265_MAIN_CMAKE_PATH..."
if [ -f "$X265_MAIN_CMAKE_PATH" ]; then
    # Set minimum version and project name (common to both)
    run_sed '1a\
cmake_minimum_required(VERSION 3.10)
' "$X265_MAIN_CMAKE_PATH" # Increased min version slightly

    # Correct project line if needed (ensure only one project line exists)
    run_sed 's/project *\(.*\)/project(x265 CXX C ASM)/' "$X265_MAIN_CMAKE_PATH"

    # Add includes (common to both, adapted from linux version)
    # Use awk to insert after the project line to be robust
    awk '
    /project *\(.*\)/ {
        print;
        print "include(CheckIncludeFiles)";
        print "include(CheckSymbolExists)";
        print "include(CheckCCompilerFlag)";
        print "include(CheckCXXCompilerFlag)";
        next
    }
    { print }
    ' "$X265_MAIN_CMAKE_PATH" > "$X265_MAIN_CMAKE_PATH.tmp" && mv "$X265_MAIN_CMAKE_PATH.tmp" "$X265_MAIN_CMAKE_PATH"
    checkStatus $? "Adding includes to CMakeLists.txt failed"

    # macOS specific policy change
    if [ "$OS_NAME" = "Darwin" ]; then
        run_sed 's/cmake_minimum_required(VERSION 3.10)/cmake_minimum_required(VERSION 3.10)\
cmake_policy(SET CMP0069 NEW)/' "$X265_MAIN_CMAKE_PATH"
        # Original macOS script had '19s/.*/...' - this is less robust. The line above inserts after min_required.
    fi
    echo "CMakeLists.txt patched."
else
    echo "ERROR: $X265_MAIN_CMAKE_PATH not found! Cannot patch."
    exit 1
fi
# --- End CMake Patches ---

# --- Define PGO Flags based on OS ---
PGO_GEN_CFLAGS=""
PGO_GEN_CXXFLAGS=""
PGO_USE_CFLAGS=""
PGO_USE_CXXFLAGS=""
LLVM_PROFDATA_CMD=""
NASM_FLAGS="-DENABLE_CET=0" # Disable CET for NASM on Linux, might be needed on macOS too?

if [ "$OS_NAME" = "Darwin" ]; then
    PGO_GEN_CFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PGO_GEN_CXXFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PROFDATA_FILE="default.profdata" # Relative to build dir
    PGO_USE_CFLAGS="-fprofile-use=${PROFDATA_FILE}"
    PGO_USE_CXXFLAGS="-fprofile-use=${PROFDATA_FILE}"
    # Find llvm-profdata
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA_CMD=$(command -v llvm-profdata)
    else
        XCODE_TOOLCHAIN_PATH=$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin
        if [ -x "$XCODE_TOOLCHAIN_PATH/llvm-profdata" ]; then
             LLVM_PROFDATA_CMD="$XCODE_TOOLCHAIN_PATH/llvm-profdata"
        else
             echo "Warning: llvm-profdata not found for x265 PGO on macOS. PGO will likely fail."
             # Allow to continue but PGO use step will fail later
        fi
    fi
else # Linux (GCC)
    PGO_GEN_CFLAGS="-fprofile-generate"
    PGO_GEN_CXXFLAGS="-fprofile-generate"
    PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile"
    PGO_USE_CXXFLAGS="-fprofile-use -Wno-missing-profile"
fi
# --- End PGO Flag Definitions ---


# --- PGO Step 1: Build Instrumented Binaries ---
mkdir -p 8bitgen
checkStatus $? "create 8bitgen directory failed"
if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    mkdir -p 10bitgen 12bitgen
    checkStatus $? "create 10/12bitgen directories failed"
fi

echo "Compiling 8bit profile generator..."
cd 8bitgen
checkStatus $? "cd 8bitgen failed"
cmake -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
      -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS" \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DENABLE_SHARED=NO \
      -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
      ../source
checkStatus $? "8bitgen configuration failed"
make -j $CPUS # Use CPUS variable
checkStatus $? "build 8bitgen failed"
cd ..
checkStatus $? "cd .. from 8bitgen failed"

if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    echo "Compiling 10bit profile generator..."
    cd 10bitgen
    checkStatus $? "cd 10bitgen failed"
    cmake -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO \
          -DHIGH_BIT_DEPTH=ON \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          ../source
    checkStatus $? "10bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 10bitgen failed"
    cd ..
    checkStatus $? "cd .. from 10bitgen failed"

    echo "Compiling 12bit profile generator..."
    cd 12bitgen
    checkStatus $? "cd 12bitgen failed"
    cmake -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO \
          -DHIGH_BIT_DEPTH=ON \
          -DMAIN12=ON \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          ../source
    checkStatus $? "12bitgen configuration failed"
    make -j $CPUS
    checkStatus $? "build 12bitgen failed"
    cd ..
    checkStatus $? "cd .. from 12bitgen failed"
fi


# --- PGO Step 2: Training Run ---
echo "Generating profiles simultaneously..."
# Run training in background
(cd 8bitgen && xz -dc "$SCRIPT_DIR/../sample/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && echo "8bit training done") &
PIDS="$!" # Collect background PIDs

if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    (cd 10bitgen && xz -dc "$SCRIPT_DIR/../sample/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && echo "10bit training done") &
    PIDS="$PIDS $!"
    (cd 12bitgen && xz -dc "$SCRIPT_DIR/../sample/stefan_sif.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/taikotemoto.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/720p_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && xz -dc "$SCRIPT_DIR/../sample/4k_bbb.y4m.xz" | ./x265 --y4m --input - -o /dev/null --preset veryslow --no-info --crf 26 && echo "12bit training done") &
    PIDS="$PIDS $!"
fi

echo "Waiting for training runs to complete..."
FAIL=0
for pid in $PIDS; do
    wait $pid || let "FAIL+=1"
done

if [ "$FAIL" -ne 0 ]; then
    echo "ERROR: $FAIL PGO training run(s) failed."
    exit 1
fi
echo "All training runs completed."


# --- PGO Step 3: Process Profile Data ---
echo "Processing PGO profiles..."
if [ "$OS_NAME" = "Darwin" ]; then
    if [ -n "$LLVM_PROFDATA_CMD" ] && [ -x "$LLVM_PROFDATA_CMD" ]; then
         echo "Merging Clang profiles using $LLVM_PROFDATA_CMD..."
         # Merge profiles from all *bitgen directories
         $LLVM_PROFDATA_CMD merge -o default.profdata */*.profraw
         checkStatus $? "llvm-profdata merge failed"
         # Clean up raw profiles
         rm -f */*.profraw
         PROFDATA_FILE_ABS="$(pwd)/default.profdata" # Absolute path for use phase
         echo "PGO profile saved to: $PROFDATA_FILE_ABS"
    else
         echo "ERROR: Cannot merge PGO profiles on macOS because llvm-profdata was not found."
         exit 1
    fi
else # Linux (GCC)
    echo "GCC PGO profile data (.gcda) generated in *bitgen directories."
    # No explicit merge needed for GCC, but ensure final build uses data from all
    # We will pass the PGO use flags during the final CMake configure step(s).
fi
echo "Profile processing completed."


# --- Final Optimized Build ---

# Clean PGO generator directories (optional but recommended)
rm -rf 8bitgen 10bitgen 12bitgen

if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    # --- Multi-bit Build ---
    echo "Starting multi-bit optimized build..."
    # Prepare build 10 bit (optimized)
    echo "Configuring/Building 10bit optimized..."
    mkdir -p 10bit
    checkStatus $? "create 10bit directory failed"
    cd 10bit/
    checkStatus $? "cd 10bit failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF \
          -DHIGH_BIT_DEPTH=ON \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          ../source
    checkStatus $? "configuration 10 bit optimized failed"
    make -j $CPUS
    checkStatus $? "build 10 bit optimized failed"
    cd ..
    checkStatus $? "cd .. from 10bit failed"

    # Prepare build 12 bit (optimized)
    echo "Configuring/Building 12bit optimized..."
    mkdir -p 12bit
    checkStatus $? "create 12bit directory failed"
    cd 12bit/
    checkStatus $? "cd 12bit failed"
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF \
          -DHIGH_BIT_DEPTH=ON -DMAIN12=ON \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          ../source
    checkStatus $? "configuration 12 bit optimized failed"
    make -j $CPUS
    checkStatus $? "build 12 bit optimized failed"
    cd ..
    checkStatus $? "cd .. from 12bit failed"

    # Prepare build 8 bit (optimized) - linking others
    echo "Configuring/Building 8bit optimized (linking 10/12bit)..."
    ln -sf 10bit/libx265.a libx265_10bit.a # Use -sf for force/symbolic
    checkStatus $? "symlink creation of 10 bit library failed"
    ln -sf 12bit/libx265.a libx265_12bit.a
    checkStatus $? "symlink creation of 12 bit library failed"
    # Build 8bit in the main directory (x265-src)
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
          -DEXTRA_LINK_FLAGS=-L. \
          -DEXTRA_LIB="x265_10bit.a;x265_12bit.a" \
          -DLINKED_10BIT=ON -DLINKED_12BIT=ON \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          source # Configure from source subdir
    checkStatus $? "configuration 8 bit optimized failed"
    make -j $CPUS
    checkStatus $? "build 8 bit optimized failed"

    # Merge libraries
    echo "Merging libraries..."
    mv libx265.a libx265_8bit.a
    checkStatus $? "move 8 bit library failed"
    if [ "$OS_NAME" = "Linux" ]; then
        # Using ar -M (thin archive) might be problematic for static linking later.
        # Using standard 'ar cru' is safer.
        echo "Creating combined archive using ar..."
        ar cru libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
        ranlib libx265.a # Create index
    elif [ "$OS_NAME" = "Darwin" ]; then
        echo "Creating combined archive using libtool..."
        libtool -static -o libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
    fi
    checkStatus $? "multi-bit library creation failed"
else
    # --- Single Build (8-bit only) ---
    echo "Starting single-bit (8bit) optimized build..."
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO \
          -DENABLE_CLI=OFF \
          -DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS" \
          source
    checkStatus $? "configuration single-bit optimized failed"
    make -j $CPUS
    checkStatus $? "build single-bit optimized failed"
fi

# --- Install ---
echo "Installing x265..."
make install
checkStatus $? "installation failed"

# --- Post-installation pkg-config fix ---
echo "Applying post-installation fix to x265.pc..."
# Determine where the .pc file was installed
PKGCONFIG_PATH_LIB="$TOOL_DIR/lib/pkgconfig/x265.pc"
PKGCONFIG_PATH_LIB64="$TOOL_DIR/lib64/pkgconfig/x265.pc"
ACTUAL_PC_FILE=""

if [ -f "$PKGCONFIG_PATH_LIB" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB"
elif [ "$OS_NAME" = "Linux" ] && [ -f "$PKGCONFIG_PATH_LIB64" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB64"
fi

if [ -z "$ACTUAL_PC_FILE" ]; then
    echo "Warning: x265.pc not found in expected pkgconfig directories after install!"
else
     echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
     # Add -lpthread if missing
     if ! grep -q -- "-lpthread" "$ACTUAL_PC_FILE"; then
         echo "Adding -lpthread to $ACTUAL_PC_FILE"
         # Append to Libs.private if it exists, otherwise append to Libs
         if grep -q "^Libs.private:" "$ACTUAL_PC_FILE"; then
             run_sed "s|^Libs.private:.*|& -lpthread|" "$ACTUAL_PC_FILE"
         else
             run_sed "s|^Libs:.*|& -lpthread|" "$ACTUAL_PC_FILE"
         fi
          checkStatus $? "modify pkgconfig file failed"
     else
          echo "-lpthread already seems present in $ACTUAL_PC_FILE."
     fi
fi

cd .. # Back to SOURCE_DIR/x265