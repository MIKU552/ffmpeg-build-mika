#!/bin/sh

# Copyright 2021 Martin Riedl
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
VERSION=$(cat "$SCRIPT_DIR/../version/openjpeg")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "openjpeg" # Use -p
cd "openjpeg/"
checkStatus $? "change directory failed"

# download source
OPENJPEG_TARBALL="openjpeg-$VERSION.tar.gz"
OPENJPEG_UNPACK_DIR="openjpeg-$VERSION"
# Use gh-proxy if needed
# download https://gh-proxy.com/https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "$OPENJPEG_TARBALL"
download https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "$OPENJPEG_TARBALL"
checkStatus $? "download failed"

# unpack
if [ -d "$OPENJPEG_UNPACK_DIR" ]; then
    rm -rf "$OPENJPEG_UNPACK_DIR"
fi
tar -zxf "$OPENJPEG_TARBALL"
checkStatus $? "unpack failed"
rm "$OPENJPEG_TARBALL" # Clean up tarball

# prepare build
BUILD_DIR="openjpeg_build"
rm -rf "$BUILD_DIR"
mkdir "$BUILD_DIR"
checkStatus $? "create build directory failed"
cd "$BUILD_DIR"
checkStatus $? "change build directory failed"
# Use consistent path for source directory relative to build directory
SOURCE_REL_PATH="../$OPENJPEG_UNPACK_DIR"
# Configure using CMake
cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_STATIC_LIBS=ON \
      -DBUILD_TESTING=OFF \
      -DBUILD_CODEC=OFF \
      "$SOURCE_REL_PATH"
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# --- Fix pkgconfig file for static linking (handle lib vs lib64) ---
echo "Applying post-installation fix to libopenjp2.pc..."
# Determine where the .pc file was installed
PKGCONFIG_PATH_LIB="$TOOL_DIR/lib/pkgconfig/libopenjp2.pc"
PKGCONFIG_PATH_LIB64="$TOOL_DIR/lib64/pkgconfig/libopenjp2.pc"
ACTUAL_PC_FILE=""

if [ -f "$PKGCONFIG_PATH_LIB" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB"
elif [ "$OS_NAME" = "Linux" ] && [ -f "$PKGCONFIG_PATH_LIB64" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB64"
fi

if [ -z "$ACTUAL_PC_FILE" ]; then
    echo "ERROR: libopenjp2.pc not found in expected pkgconfig directories after install!"
    exit 1
else
    echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
    # Add -lm -lpthread if they are not already present in Libs.private or Libs
    LIBS_LINE=$(grep "^Libs:" "$ACTUAL_PC_FILE")
    LIBS_PRIVATE_LINE=$(grep "^Libs.private:" "$ACTUAL_PC_FILE")

    NEEDS_PTHREAD="YES"
    NEEDS_M="YES"

    # Check if flags exist in either Libs or Libs.private
    if echo "$LIBS_LINE $LIBS_PRIVATE_LINE" | grep -q -- "-lpthread"; then
        NEEDS_PTHREAD="NO"
    fi
    if echo "$LIBS_LINE $LIBS_PRIVATE_LINE" | grep -q -- "-lm"; then
        NEEDS_M="NO"
    fi

    FLAGS_TO_ADD=""
    if [ "$NEEDS_PTHREAD" = "YES" ]; then FLAGS_TO_ADD="$FLAGS_TO_ADD -lpthread"; fi
    if [ "$NEEDS_M" = "YES" ]; then FLAGS_TO_ADD="$FLAGS_TO_ADD -lm"; fi

    if [ -n "$FLAGS_TO_ADD" ]; then
        echo "Adding flags '$FLAGS_TO_ADD' to $ACTUAL_PC_FILE"
        # Append to Libs.private if it exists, otherwise append to Libs
        if grep -q "^Libs.private:" "$ACTUAL_PC_FILE"; then
            run_sed "s|^Libs.private:.*|&${FLAGS_TO_ADD}|" "$ACTUAL_PC_FILE"
        else
            # Append to Libs line
             run_sed "s|^Libs:.*|&${FLAGS_TO_ADD}|" "$ACTUAL_PC_FILE"
             # OR add Libs.private line if Libs is complex
             # echo "Libs.private:$FLAGS_TO_ADD" >> "$ACTUAL_PC_FILE"
        fi
         checkStatus $? "modify pkgconfig file failed"
    else
        echo "Required flags (-lm, -lpthread) already seem present in $ACTUAL_PC_FILE."
    fi
fi
# --- End pkgconfig fix ---

cd .. # Back to parent dir (source/openjpeg)