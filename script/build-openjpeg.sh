#!/bin/sh

# Copyright 2021 Martin Riedl
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
# Reconstruct LOG_DIR path
LOG_DIR="$(pwd)/log"

# load functions
. $SCRIPT_DIR/functions.sh

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
download https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "$OPENJPEG_TARBALL"
checkStatus $? "download failed"

# unpack
if [ -d "$OPENJPEG_UNPACK_DIR" ]; then
    rm -rf "$OPENJPEG_UNPACK_DIR"
fi
tar -zxf "$OPENJPEG_TARBALL"
checkStatus $? "unpack failed"

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
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_STATIC_LIBS=ON \
      -DBUILD_TESTING=OFF \
      "$SOURCE_REL_PATH"
      # NOTE: Removed -DCMAKE_INSTALL_LIBDIR=lib to allow default behavior
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# --- Fix pkgconfig file for static linking (handle lib vs lib64) ---
echo "Applying post-installation fix to libopenjp2.pc..."
PKGCONFIG_PATH_LIB="$TOOL_DIR/lib/pkgconfig/libopenjp2.pc"
PKGCONFIG_PATH_LIB64="$TOOL_DIR/lib64/pkgconfig/libopenjp2.pc"
ACTUAL_PC_FILE=""

if [ -f "$PKGCONFIG_PATH_LIB" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB"
    echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
elif [ -f "$PKGCONFIG_PATH_LIB64" ]; then
    ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB64"
    echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
else
    echo "ERROR: libopenjp2.pc not found in $TOOL_DIR/lib/pkgconfig or $TOOL_DIR/lib64/pkgconfig after install!"
    # Optionally list contents for debugging:
    # echo "Contents of $TOOL_DIR/lib:" && ls -lR "$TOOL_DIR/lib/"
    # echo "Contents of $TOOL_DIR/lib64:" && ls -lR "$TOOL_DIR/lib64/"
    exit 1 # Fail the build
fi

# Add -lm -lpthread if they are not already present in Libs.private
# Use grep -q to check if pattern exists; only run sed if pattern is found and needs modification
if grep -q "Libs.private:" "$ACTUAL_PC_FILE"; then
    # Check if flags are already there to avoid adding duplicates
    if ! grep "Libs.private:.*-lm" "$ACTUAL_PC_FILE" || ! grep "Libs.private:.*-lpthread" "$ACTUAL_PC_FILE"; then
        echo "Adding -lm -lpthread to Libs.private in $ACTUAL_PC_FILE"
        # Use a temporary variable for the replacement string to handle potential special characters
        # Read existing flags, append new ones if missing (more robust)
        EXISTING_LIBS=$(grep "^Libs.private:" "$ACTUAL_PC_FILE" | sed 's/^Libs.private://')
        NEW_LIBS="$EXISTING_LIBS"
        # Add -lm if missing
        if ! echo "$EXISTING_LIBS" | grep -q -- "-lm"; then
            NEW_LIBS="$NEW_LIBS -lm"
        fi
        # Add -lpthread if missing
        if ! echo "$EXISTING_LIBS" | grep -q -- "-lpthread"; then
            NEW_LIBS="$NEW_LIBS -lpthread"
        fi
        # Remove leading/trailing whitespace (optional)
        NEW_LIBS=$(echo "$NEW_LIBS" | awk '{$1=$1};1')

        # Replace the whole line starting with Libs.private:
        sed -i.original -e "s|^Libs.private:.*|Libs.private: $NEW_LIBS|g" "$ACTUAL_PC_FILE"
        checkStatus $? "modify pkgconfig file failed"
    else
        echo "-lm and -lpthread already seem present in Libs.private."
    fi
else
    # If Libs.private doesn't exist, add it with the flags
    echo "Adding 'Libs.private: -lm -lpthread' to $ACTUAL_PC_FILE"
    echo "Libs.private: -lm -lpthread" >> "$ACTUAL_PC_FILE"
    checkStatus $? "add Libs.private line failed"
    # echo "Warning: 'Libs.private:' line not found in $ACTUAL_PC_FILE. Cannot add flags automatically."
    # Depending on needs, might need to add the line or ignore. Let's add it.
fi
# --- End pkgconfig fix ---


# cd back to base dir (source/openjpeg)
cd ..
checkStatus $? "cd back failed"

# Add success marker logic if you are using it
# touch "$LOG_DIR/build-openjpeg.success"