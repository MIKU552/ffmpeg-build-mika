#!/bin/sh

# Copyright 2022 Martin Riedl
# Copyright 2024 Hayden Zheng
# Merged for Linux & macOS compatibility - Reverted macOS logic based on original working script

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
SVT_TARBALL="SVT-AV1-$VERSION.tar.gz"
SVT_UNPACK_DIR="SVT-AV1-$VERSION"
# Consider adding proxy if needed: https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$VERSION/$SVT_TARBALL
download https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$VERSION/$SVT_TARBALL "$SVT_TARBALL"
checkStatus $? "download failed"

# unpack
tar -zxf "$SVT_TARBALL"
checkStatus $? "unpack failed"
rm "$SVT_TARBALL" # Clean up

# prepare build
cd "$SVT_UNPACK_DIR/" # cd into unpacked dir first
checkStatus $? "change directory failed"

# OS-Specific sed patches
LLVM_PROFDATA_CMD_CMAKE="" # CMake arg to specify llvm-profdata path

if [ "$OS_NAME" = "Darwin" ]; then
    # --- macOS Specific Logic - Reverted to Original ---
    echo "Applying original macOS sed patches..."
    # WARNING: These sed commands rely on specific line numbers/patterns in the original files
    # Patch pgohelper.cmake (Lines based on original script)
    run_sed '36s/.y4m/.y4m.xz/g' Build/pgohelper.cmake
    run_sed '43s/\${SvtAv1EncApp} -i \${video} -b "\${BUILD_DIRECTORY}\/\${videoname}.ivf" --preset 2 --film-grain 8 --tune 0/"xz -dc \${video} | \${SvtAv1EncApp} -i - -b \\"\${BUILD_DIRECTORY}\/\${videoname}.ivf\\" --preset 2 --film-grain 8 --tune 0 --lookahead 120"/g' Build/pgohelper.cmake
    run_sed '49s/\${ENCODING_COMMAND}/sh -c "\${ENCODING_COMMAND}"/g' Build/pgohelper.cmake
    checkStatus $? "Editing Build/pgohelper.cmake failed"

    # Patch CMakeLists.txt (Line based on original script)
    run_sed '280,281s/PGO_DIR}/PGO_DIR} -mllvm -vp-counters-per-site=2048/g' CMakeLists.txt
    checkStatus $? "Editing CMakeLists.txt failed"

    # Find llvm-profdata using xcode-select path (like original script)
    XCODE_SELECT_PATH=$(xcode-select -p 2>/dev/null)
    if [ -n "$XCODE_SELECT_PATH" ] && [ -x "$XCODE_SELECT_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata" ]; then
        LLVM_PROFDATA_CMD_CMAKE="-DLLVM_PROFDATA=$XCODE_SELECT_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata"
        echo "Found llvm-profdata via xcode-select."
    else
        # Fallback to searching PATH
        if command -v llvm-profdata >/dev/null 2>&1; then
            LLVM_PROFDATA_CMD_CMAKE="-DLLVM_PROFDATA=$(command -v llvm-profdata)"
             echo "Found llvm-profdata in PATH."
        else
            echo "WARNING: llvm-profdata not found via xcode-select or PATH. PGO might fail on macOS."
            # Keep variable empty if not found
            LLVM_PROFDATA_CMD_CMAKE=""
        fi
    fi
    # --- End macOS Specific Logic ---
else
    # Linux specific patches (if any needed in the future)
    echo "Applying Linux sed patches (if any)..."
    # These are likely common needed patches
    run_sed '36s/.y4m/.y4m.xz/g' Build/pgohelper.cmake
    run_sed '43s/\${SvtAv1EncApp} -i \${video} -b "\${BUILD_DIRECTORY}\/\${videoname}.ivf" --preset 2 --film-grain 8 --tune 0/"xz -dc \${video} | \${SvtAv1EncApp} -i - -b \\"\${BUILD_DIRECTORY}\/\${videoname}.ivf\\" --preset 2 --film-grain 8 --tune 0 --lookahead 120"/g' Build/pgohelper.cmake
    run_sed '49s/\${ENCODING_COMMAND}/sh -c "\${ENCODING_COMMAND}"/g' Build/pgohelper.cmake
fi


# Create build directory (common)
mkdir -p "build"
checkStatus $? "create build directory failed"
cd "build/"
checkStatus $? "change directory to build failed"

echo "Configuring SVT-AV1..."
# Use CMake configuration logic based on OS
# Common flags
CMAKE_COMMON_FLAGS="-DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR \
      -DSVT_AV1_LTO=ON \
      -DSVT_AV1_PGO=ON \
      -DSVT_AV1_PGO_CUSTOM_VIDEOS=$SCRIPT_DIR/../sample \
      -DBUILD_SHARED_LIBS=NO"

if [ "$OS_NAME" = "Darwin" ]; then
    # macOS: Add LLVM_PROFDATA flag if found, DO NOT set CMAKE_*_FLAGS explicitly
    # shellcheck disable=SC2086
    cmake ${CMAKE_COMMON_FLAGS} \
          ${LLVM_PROFDATA_CMD_CMAKE} \
          ..
    checkStatus $? "macOS configuration failed"
else
    # Linux: Rely on -DSVT_AV1_PGO=ON for GCC PGO flags
    # shellcheck disable=SC2086
    cmake ${CMAKE_COMMON_FLAGS} \
          ..
    checkStatus $? "Linux configuration failed"
fi


# build PGO profile (Common command)
echo "Running SVT-AV1 PGO Training..."
make RunPGO -j $CPUS
checkStatus $? "PGO build/training failed"

# Final install (Common command)
echo "Installing SVT-AV1 (Optimized Build)..."
make install
checkStatus $? "installation failed"

cd ../.. # Back to SOURCE_DIR/svt-av1