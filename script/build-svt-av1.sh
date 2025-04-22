#!/bin/sh

# Copyright 2022 Martin Riedl
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

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/svt-av1")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "svt-av1" # Use -p
cd "svt-av1/"
checkStatus $? "change directory failed"

# download source
SVT_TARBALL="SVT-AV1-$VERSION.tar.gz" # Match filename used in linux script
SVT_UNPACK_DIR="SVT-AV1-$VERSION"
download https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$VERSION/$SVT_TARBALL "$SVT_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$SVT_TARBALL"
checkStatus $? "unpack failed"
rm "$SVT_TARBALL" # Clean up

# prepare build
cd "$SVT_UNPACK_DIR/" # cd into unpacked dir first
checkStatus $? "change directory failed"

# Modify pgo helper for xz samples and command execution
echo "Patching SVT-AV1 build files..."
run_sed 's/\.y4m/\.y4m\.xz/g' Build/pgohelper.cmake
run_sed 's/${SvtAv1EncApp} -i ${video} -b "\${BUILD_DIRECTORY}\/\${videoname}.ivf" --preset 2 --film-grain 8 --tune 0/xz -dc ${video} | ${SvtAv1EncApp} -i - -b \\"\${BUILD_DIRECTORY}\/\${videoname}.ivf\\" --preset 2 --film-grain 8 --tune 0 --lookahead 120/g' Build/pgohelper.cmake
run_sed 's/${ENCODING_COMMAND}/sh -c "${ENCODING_COMMAND}"/g' Build/pgohelper.cmake

# Add PGO generate flags conditionally
PGO_GEN_FLAG_CMAKE=""
LLVM_PROFDATA_CMD_CMAKE=""
if [ "$OS_NAME" = "Darwin" ]; then
    # Clang flags - add counters flag
    PGO_GEN_FLAG_CMAKE="-DCMAKE_C_FLAGS_INIT=-fprofile-generate -mllvm -vp-counters-per-site=2048 -DCMAKE_CXX_FLAGS_INIT=-fprofile-generate -mllvm -vp-counters-per-site=2048"
     # Find llvm-profdata
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA_CMD_CMAKE="-DLLVM_PROFDATA=$(command -v llvm-profdata)"
    else
        XCODE_TOOLCHAIN_PATH=$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin
        if [ -x "$XCODE_TOOLCHAIN_PATH/llvm-profdata" ]; then
            LLVM_PROFDATA_CMD_CMAKE="-DLLVM_PROFDATA=$XCODE_TOOLCHAIN_PATH/llvm-profdata"
        else
            echo "WARNING: llvm-profdata not found for SVT-AV1 PGO on macOS. PGO might fail."
        fi
    fi
else # Linux (GCC)
    # GCC flags
    PGO_GEN_FLAG_CMAKE="-DCMAKE_C_FLAGS_INIT=-fprofile-generate -DCMAKE_CXX_FLAGS_INIT=-fprofile-generate"
    # LLVM_PROFDATA not needed for GCC
fi

# Remove clang-specific flag injection from CMakeLists.txt that was in macOS script
# run_sed '280,281s/PGO_DIR}/PGO_DIR} -mllvm -vp-counters-per-site=2048/g' CMakeLists.txt

# Create build directory
mkdir -p "build" # Create inside SVT_UNPACK_DIR
checkStatus $? "create build directory failed"
cd "build/"
checkStatus $? "change directory to build failed"

echo "Configuring SVT-AV1..."
# Configure for PGO/LTO
# Pass PGO flags via CMAKE_*_FLAGS_INIT to avoid overriding toolchain flags
# shellcheck disable=SC2086 # Allow word splitting for flags
cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
      -DSVT_AV1_LTO=ON \
      -DSVT_AV1_PGO=ON \
      -DSVT_AV1_PGO_CUSTOM_VIDEOS="$SCRIPT_DIR/../sample" \
      -DBUILD_SHARED_LIBS=NO \
      $PGO_GEN_FLAG_CMAKE \
      $LLVM_PROFDATA_CMD_CMAKE \
      .. # Source directory is parent
checkStatus $? "configuration failed"

# build PGO profile
echo "Running SVT-AV1 PGO Training..."
make RunPGO -j $CPUS
checkStatus $? "PGO build/training failed"

# Final install (builds optimized version using PGO data)
echo "Installing SVT-AV1 (Optimized Build)..."
make install
checkStatus $? "installation failed"

cd ../.. # Back to SOURCE_DIR/svt-av1