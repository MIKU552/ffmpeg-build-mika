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

# load functions
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/vvdec")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "vvdec" # Use -p
cd "vvdec/"
checkStatus $? "change directory failed"

# download source
VVDEC_TARBALL="vvdec-$VERSION.tar.gz" # Use consistent naming
VVDEC_UNPACK_DIR="vvdec-$VERSION"
# Use gh-proxy if needed
# download https://gh-proxy.com/https://github.com/fraunhoferhhi/vvdec/archive/$VERSION.tar.gz "$VVDEC_TARBALL"
download https://github.com/fraunhoferhhi/vvdec/archive/$VERSION.tar.gz "$VVDEC_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$VVDEC_TARBALL"
checkStatus $? "unpack failed"
rm "$VVDEC_TARBALL" # Clean up

# --- PGO Step 1: Build Instrumented Binary ---
echoSection "Build vvdec PGO Generator"
cd "$VVDEC_UNPACK_DIR/"
checkStatus $? "change directory failed"

mkdir -p "pgogen"
checkStatus $? "create directory failed"
cd "pgogen/"
checkStatus $? "change directory failed"

PGO_GEN_CFLAGS=""
PGO_GEN_CXXFLAGS=""
if [ "$OS_NAME" = "Darwin" ]; then
    # Clang flags
    PGO_GEN_CFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PGO_GEN_CXXFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
else # Linux (GCC)
    # GCC flags
    PGO_GEN_CFLAGS="-fprofile-generate"
    PGO_GEN_CXXFLAGS="-fprofile-generate"
fi

cmake -S .. -B build/release-static -G 'Ninja' \
      -DVVDEC_INSTALL_VVDECAPP=ON \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_INSTALL_PREFIX=$(pwd)/install-prefix \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
      -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS"
checkStatus $? "configuration pgogen failed"

cmake --build build/release-static -j $CPUS
checkStatus $? "build pgogen failed"

cmake --build build/release-static --target install
checkStatus $? "pgogen installation failed"

# --- PGO Step 2: Training Run ---
echoSection "Run vvdec PGO Training"
# Check if training input files (bitstreams from vvenc) exist
VVENC_SOURCE_DIR="$SOURCE_DIR/vvenc" # Assumes vvenc was built before vvdec
echo "Looking for VVC bitstreams in $VVENC_SOURCE_DIR..."
if [ ! -f "$VVENC_SOURCE_DIR/stefan_sif.266" ] || \
   [ ! -f "$VVENC_SOURCE_DIR/taikotemoto.266" ] || \
   [ ! -f "$VVENC_SOURCE_DIR/720p_bbb.266" ] || \
   [ ! -f "$VVENC_SOURCE_DIR/4k_bbb.266" ]; then
    echo "Warning: VVC bitstream files from vvenc build not found in $VVENC_SOURCE_DIR."
    echo "vvdec PGO training requires vvenc to be built first with sample encoding."
    echo "Skipping vvdec PGO training run. Final build will not be PGO-optimized."
    # Skip profile merging and set flags for non-PGO build
    ENABLE_VVDEC_PGO="NO" # Use a flag to skip PGO-use steps later
else
    ENABLE_VVDEC_PGO="YES"
    # Run training
    install-prefix/bin/vvdecapp -b "$VVENC_SOURCE_DIR/stefan_sif.266" -o /dev/null
    checkStatus $? "PGO training failed on stefan_sif.266"
    install-prefix/bin/vvdecapp -b "$VVENC_SOURCE_DIR/taikotemoto.266" -o /dev/null
    checkStatus $? "PGO training failed on taikotemoto.266"
    install-prefix/bin/vvdecapp -b "$VVENC_SOURCE_DIR/720p_bbb.266" -o /dev/null
    checkStatus $? "PGO training failed on 720p_bbb.266"
    install-prefix/bin/vvdecapp -b "$VVENC_SOURCE_DIR/4k_bbb.266" -o /dev/null
    checkStatus $? "PGO training failed on 4k_bbb.266"

    # --- PGO Step 3: Process Profile Data ---
    echoSection "Process vvdec PGO Data"
    PROFDATA_FILE="../default.profdata" # Save merged data in parent dir
    if [ "$OS_NAME" = "Darwin" ]; then
        # Find llvm-profdata
        LLVM_PROFDATA_CMD=""
         if command -v llvm-profdata >/dev/null 2>&1; then
            LLVM_PROFDATA_CMD="llvm-profdata"
        else
            XCODE_TOOLCHAIN_PATH=$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin
            if [ -x "$XCODE_TOOLCHAIN_PATH/llvm-profdata" ]; then
                LLVM_PROFDATA_CMD="$XCODE_TOOLCHAIN_PATH/llvm-profdata"
            else
                echo "ERROR: llvm-profdata not found. Cannot merge vvdec PGO profiles on macOS."
                exit 1
            fi
        fi
        echo "Merging Clang PGO profiles using: $LLVM_PROFDATA_CMD"
        # Find .profraw files (might be in install-prefix or build/release-static?)
        # Let's assume they are in the current dir (pgogen) for now
        $LLVM_PROFDATA_CMD merge -o "$PROFDATA_FILE" ./*.profraw
        checkStatus $? "llvm-profdata merge failed"
        rm -f ./*.profraw # Clean up raw profiles
    else # Linux (GCC)
        echo "GCC PGO profile data (.gcda files) generated."
        # No explicit merge needed for GCC.
    fi
fi # End PGO Training Run

# Clean build artifacts from pgogen stage
cd .. # Back to vvdec-$VERSION
# vvdec uses 'make realclean' if Makefile exists, otherwise try cmake clean
if [ -f Makefile ]; then
    make realclean
    echo "Used 'make realclean'"
else
    # Attempt cmake clean if pgogen build dir exists
    if [ -d "pgogen/build/release-static" ]; then
         echo "Using 'cmake --build ... --target clean'"
         cmake --build pgogen/build/release-static --target clean
    fi
fi
# Remove the pgogen dir entirely? Optional.
# rm -rf pgogen


# --- Final Optimized Build ---
echoSection "Build vvdec Optimized"
mkdir -p "build" # Final build directory
checkStatus $? "create final build directory failed"
cd "build/"
checkStatus $? "change directory to final build failed"

PGO_USE_CFLAGS=""
PGO_USE_CXXFLAGS=""
PROFDATA_ARG=""

if [ "$ENABLE_VVDEC_PGO" = "YES" ]; then
    if [ "$OS_NAME" = "Darwin" ]; then
        # Clang PGO use flags
        PROFDATA_PATH_ARG="../default.profdata" # Path relative to build dir
        PGO_USE_CFLAGS="-fprofile-use=$PROFDATA_PATH_ARG"
        PGO_USE_CXXFLAGS="-fprofile-use=$PROFDATA_PATH_ARG"
        echo "Using Clang PGO use flags with profile: $PROFDATA_PATH_ARG"
    else # Linux (GCC)
        # GCC PGO use flags (profile data location is handled differently by GCC)
        PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile"
        PGO_USE_CXXFLAGS="-fprofile-use -Wno-missing-profile"
        echo "Using GCC PGO use flags"
    fi
else
    echo "Building vvdec without PGO optimization."
fi


cmake -S .. -B build/release-static -G 'Ninja' \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_INSTALL_PREFIX=$TOOL_DIR \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
      -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS"
checkStatus $? "Final configuration failed"

# Build optimized
cmake --build build/release-static -j $CPUS
checkStatus $? "Final build failed"

# Install optimized
cmake --build build/release-static --target install
checkStatus $? "Final installation failed"

cd ../.. # Back to SOURCE_DIR/vvdec