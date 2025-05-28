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

# load functions
. $SCRIPT_DIR/functions.sh

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "sdl"
checkStatus $? "create directory failed"
cd "sdl/"
checkStatus $? "change directory failed"

# Get latest SDL2 version from GitHub API
echo "Fetching latest SDL2 version from GitHub..."
LATEST_SDL_TAG=$(get_latest_github_release_tag "libsdl-org/SDL")
checkStatus $? "Failed to fetch latest SDL2 tag from GitHub"
echo "Latest SDL2 tag: $LATEST_SDL_TAG" # Should be like release-X.Y.Z

LATEST_SDL_VERSION=$(echo "$LATEST_SDL_TAG" | sed 's/^release-//') # Remove 'release-' prefix
checkStatus $? "Failed to parse SDL2 version from tag (sed)"
echo "Latest SDL2 version: $LATEST_SDL_VERSION"

# download source
SDL_TARBALL="SDL2-${LATEST_SDL_VERSION}.tar.gz" # Standard tarball name
SDL_DOWNLOAD_URL="https://www.libsdl.org/release/${SDL_TARBALL}" # Use official site download
SDL_UNPACK_DIR="SDL2-${LATEST_SDL_VERSION}"

download "$SDL_DOWNLOAD_URL" "SDL2.tar.gz" # Keep downloaded name as SDL2.tar.gz for consistency
checkStatus $? "download failed"

# unpack
tar -zxf "SDL2.tar.gz"
checkStatus $? "unpack failed"
cd "$SDL_UNPACK_DIR/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no --enable-system-iconv=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
