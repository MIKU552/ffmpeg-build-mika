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
# Note: CPUS not used by original script

# load functions
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "pkg-config" # Use -p
cd "pkg-config/"
checkStatus $? "change directory failed"

# download source
PKG_SUBDIR="pkg-config-src" # Use subdirectory
mkdir -p "$PKG_SUBDIR"

echo "Fetching latest pkg-config version from freedesktop.org..."
LATEST_PKGCONFIG_VERSION=$(curl -sL https://pkg-config.freedesktop.org/releases/ | \
    grep -oP 'href="pkg-config-([0-9\.]+)\.tar\.gz"' | \
    sed -E 's|href="pkg-config-([0-9\.]+)\.tar\.gz"|\1|' | \
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)*$' | \
    sort -V | tail -n 1)
checkStatus $? "Failed to fetch latest pkg-config version"
echo "Latest pkg-config version: $LATEST_PKGCONFIG_VERSION"

download https://pkg-config.freedesktop.org/releases/pkg-config-$LATEST_PKGCONFIG_VERSION.tar.gz "pkg-config.tar.gz"
checkStatus $? "download of pkg-config failed"

# unpack
tar -zxf "pkg-config.tar.gz" -C "$PKG_SUBDIR" --strip-components=1
checkStatus $? "unpack pkg-config failed"
rm pkg-config.tar.gz # Clean up tarball
cd "$PKG_SUBDIR/"
checkStatus $? "change directory failed"

# --- Windows specific stuff (Keep for reference, though not target platforms) ---
DETECTED_OS_INTERNAL="$(uname -o 2> /dev/null)" # Use different var name
echo "detected internal OS type: $DETECTED_OS_INTERNAL"
if [ "$DETECTED_OS_INTERNAL" = "Msys" ]; then
    echo "Windows (MSYS) specific patches would be applied here if needed."
    # (Patch code omitted as Windows is not a target)
fi
# --- End Windows specific ---


# --- Add macOS specific CFLAGS ---
CONFIGURE_CFLAGS=""
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Adding -Wno-int-conversion CFLAG for macOS glib build"
    CONFIGURE_CFLAGS="CFLAGS=-Wno-int-conversion"
fi

# prepare build
# Construct pkg-config search path carefully, including potential lib64
PKG_CONFIG_SEARCH_PATH="$TOOL_DIR/lib/pkgconfig"
if [ "$OS_NAME" = "Linux" ]; then
    PKG_CONFIG_SEARCH_PATH="$PKG_CONFIG_SEARCH_PATH:$TOOL_DIR/lib64/pkgconfig"
fi

./configure --prefix="$TOOL_DIR" \
            --with-pc-path="$PKG_CONFIG_SEARCH_PATH" \
            --with-internal-glib \
            "$CONFIGURE_CFLAGS" # Add CFLAGS here
checkStatus $? "configuration of pkg-config failed"

# build
make
checkStatus $? "build of pkg-config failed"

# install
make install
checkStatus $? "installation of pkg-config failed"