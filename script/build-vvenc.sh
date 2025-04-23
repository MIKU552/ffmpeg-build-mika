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
VERSION=$(cat "$SCRIPT_DIR/../version/vvenc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "vvenc" # Use -p
cd "vvenc/"
checkStatus $? "change directory failed"

# download source
VVENC_TARBALL="vvenc-$VERSION.tar.gz"
VVENC_UNPACK_DIR="vvenc-$VERSION"
download https://github.com/fraunhoferhhi/vvenc/archive/$VERSION.tar.gz "$VVENC_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$VVENC_TARBALL"
checkStatus $? "unpack failed"
rm "$VVENC_TARBALL" # Clean up

# --- PGO Step 1: Build Instrumented Binary ---
echoSection "Build vvenc PGO Generator"
cd "$VVENC_UNPACK_DIR/"
checkStatus $? "change directory failed"

mkdir -p "pgogen"
checkStatus $? "create directory failed"
cd "pgogen/"
checkStatus $? "change directory failed"

PGO_GEN_CFLAGS=""
PGO_GEN_CXXFLAGS=""
if [ "$OS_NAME" = "Darwin" ]; then
    PGO_GEN_CFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PGO_GEN_CXXFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
else # Linux (GCC)
    PGO_GEN_CFLAGS="-fprofile-generate"
    PGO_GEN_CXXFLAGS="-fprofile-generate"
fi

cmake -S .. -B build/release-static -G 'Ninja' \
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
echoSection "Run vvenc PGO Training"
SAMPLE_FILES_EXIST="YES"
for sample in stefan_sif taikotemoto 720p_bbb 4k_bbb; do
    if [ ! -f "$SCRIPT_DIR/../sample/${sample}.y4m.xz" ]; then
        echo "Warning: Sample file $SCRIPT_DIR/../sample/${sample}.y4m.xz not found."
        SAMPLE_FILES_EXIST="NO"
    fi
done

if [ "$SAMPLE_FILES_EXIST" = "NO" ]; then
    echo "Required sample files missing. Skipping vvenc PGO training."
    ENABLE_VVENC_PGO="NO"
else
    ENABLE_VVENC_PGO="YES"
    echo "Generating profiles (this may take a very long time)..."
    OUTPUT_BITSTREAM_DIR=".." # Save bitstreams in parent dir (vvenc-$VERSION)
    xz -dc "$SCRIPT_DIR/../sample/stefan_sif.y4m.xz" | install-prefix/bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o "$OUTPUT_BITSTREAM_DIR/stefan_sif.266"
    checkStatus $? "PGO training failed on stefan_sif"
    # Consider commenting out slower runs if needed
    xz -dc "$SCRIPT_DIR/../sample/taikotemoto.y4m.xz" | install-prefix/bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o "$OUTPUT_BITSTREAM_DIR/taikotemoto.266"
    checkStatus $? "PGO training failed on taikotemoto"
    xz -dc "$SCRIPT_DIR/../sample/720p_bbb.y4m.xz" | install-prefix/bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o "$OUTPUT_BITSTREAM_DIR/720p_bbb.266"
    checkStatus $? "PGO training failed on 720p_bbb"
    xz -dc "$SCRIPT_DIR/../sample/4k_bbb.y4m.xz" | install-prefix/bin/vvencapp -i - --y4m --preset slow -q 30 -t $CPUS -o "$OUTPUT_BITSTREAM_DIR/4k_bbb.266"
    checkStatus $? "PGO training failed on 4k_bbb"

    # --- PGO Step 3: Process Profile Data ---
    echoSection "Process vvenc PGO Data"
    # Define relative path for output, but capture absolute path *before* merge
    PROFDATA_FILE_REL="../default.profdata"
    PROFDATA_FILE_ABS="$(pwd)/$PROFDATA_FILE_REL" # Path relative to current dir (pgogen)
    # Resolve ".." to get clean absolute path to where the file *will be* created
    PROFDATA_FILE_ABS=$(cd "$(dirname "$PROFDATA_FILE_ABS")" && pwd)/$(basename "$PROFDATA_FILE_ABS")

    if [ "$OS_NAME" = "Darwin" ]; then
        LLVM_PROFDATA_CMD=""
        if command -v llvm-profdata >/dev/null 2>&1; then
            LLVM_PROFDATA_CMD="llvm-profdata"
        else
            XCODE_TOOLCHAIN_PATH=$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin
            if [ -x "$XCODE_TOOLCHAIN_PATH/llvm-profdata" ]; then
                LLVM_PROFDATA_CMD="$XCODE_TOOLCHAIN_PATH/llvm-profdata"
            else
                echo "ERROR: llvm-profdata not found. Cannot merge vvenc PGO profiles on macOS."
                exit 1
            fi
        fi
        echo "Merging Clang PGO profiles using: $LLVM_PROFDATA_CMD"
        # Execute merge using the relative output path
        $LLVM_PROFDATA_CMD merge -o "$PROFDATA_FILE_REL" ./*.profraw
        MERGE_STATUS=$? # Capture exit status

        # Clean up raw profiles regardless of merge status for idempotency
        rm -f ./*.profraw

        # Check merge status AFTER cleanup attempt
        checkStatus $MERGE_STATUS "llvm-profdata merge failed"

        # Verify the merged file exists at the calculated absolute path
        if [ ! -f "$PROFDATA_FILE_ABS" ]; then
             echo "ERROR: Merged profile data not found at expected absolute path: $PROFDATA_FILE_ABS"
             echo "llvm-profdata merge might have failed silently or produced no output."
             exit 1
        fi
         echo "PGO profile successfully merged to: $PROFDATA_FILE_ABS"

    else # Linux (GCC)
        echo "GCC PGO profile data (.gcda files) generated."
        # For GCC, PGO use flags don't need explicit profile path, but we need a placeholder
        PROFDATA_FILE_ABS="gcc" # Use a non-path placeholder for GCC logic below
    fi
fi # End PGO Training Run check

# Clean build artifacts from pgogen stage
cd .. # Back to vvenc-$VERSION
if [ -f Makefile ]; then make realclean; else cmake --build pgogen/build/release-static --target clean > /dev/null 2>&1 || true; fi

# --- Final Optimized Build ---
echoSection "Build vvenc Optimized"
mkdir -p "build"
checkStatus $? "create final build directory failed"
cd "build/"
checkStatus $? "change directory to final build failed"

PGO_USE_CFLAGS=""
PGO_USE_CXXFLAGS=""

# Set PGO use flags only if PGO training was successful
if [ "$ENABLE_VVENC_PGO" = "YES" ]; then
    if [ "$OS_NAME" = "Darwin" ]; then
        # Use the absolute path captured earlier
        PGO_USE_CFLAGS="-fprofile-use=$PROFDATA_FILE_ABS -Wno-backend-plugin"
        PGO_USE_CXXFLAGS="-fprofile-use=$PROFDATA_FILE_ABS -Wno-backend-plugin"
        echo "Using Clang PGO use flags with profile: $PROFDATA_FILE_ABS"
    else # Linux (GCC)
        # GCC doesn't need the path, just the flags
        PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile"
        PGO_USE_CXXFLAGS="-fprofile-use -Wno-missing-profile"
        echo "Using GCC PGO use flags"
    fi
else
    echo "Building vvenc without PGO optimization (PGO training was skipped or failed)."
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

cd ../.. # Back to SOURCE_DIR/vvenc