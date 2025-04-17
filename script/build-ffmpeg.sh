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
OUT_DIR=$4
CPUS=$5
FFMPEG_SNAPSHOT=$6
SKIP_VVDEC_PATCH=$7
FFMPEG_LIB_FLAGS=$8
ENABLE_FFMPEG_PGO=$9 # Added PGO flag

# load functions
. $SCRIPT_DIR/functions.sh

# version
if [ $FFMPEG_SNAPSHOT = "YES" ]; then
    VERSION="snapshot"
else
    # load version
    VERSION=$(cat "$SCRIPT_DIR/../version/ffmpeg")
    checkStatus $? "load version failed"
fi
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "ffmpeg"
checkStatus $? "create directory failed"
cd "ffmpeg/"
checkStatus $? "change directory failed"

# download ffmpeg source
download https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.bz2 "ffmpeg.tar.bz2"
checkStatus $? "ffmpeg download failed"

# unpack ffmpeg
mkdir "ffmpeg"
checkStatus $? "create directory failed"
bunzip2 "ffmpeg.tar.bz2"
checkStatus $? "unpack failed (bunzip2)"
tar -xf ffmpeg.tar -C ffmpeg --strip-components=1
checkStatus $? "unpack failed (tar)"
cd "ffmpeg/"
checkStatus $? "change directory failed"

# Define directories and files
FFMPEG_BUILD_DIR="$SOURCE_DIR/ffmpeg/ffmpeg"
FFMPEG_PROFDATA_FILE="$FFMPEG_BUILD_DIR/default.profdata" # Path for potential merged profile (though not used by default GCC workflow)
SAMPLE_DIR="$SCRIPT_DIR/../sample" # Assuming samples are here

# prepare build
EXTRA_VERSION="MiKayule-Group"
FF_FLAGS="-L${TOOL_DIR}/lib -I${TOOL_DIR}/include"

# Set PKG_CONFIG_PATH dynamically
export PKG_CONFIG_PATH="$TOOL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

# Common configure arguments
CONFIGURE_ARGS="--prefix=\"$OUT_DIR\" --pkg-config-flags=\"--static\" --disable-static --enable-shared --enable-lto --extra-version=\"$EXTRA_VERSION\" --enable-gray --enable-libxml2 $FFMPEG_LIB_FLAGS"

if [ $SKIP_VVDEC_PATCH = "NO" ]; then
    wget -O libvvdec.patch https://raw.githubusercontent.com/wiki/fraunhoferhhi/vvdec/data/patch/v6-0001-avcodec-add-external-dec-libvvdec-for-H266-VVC.patch
    checkStatus $? "download vvdec patch failed"
    patch -p 1 < libvvdec.patch
    checkStatus $? "apply vvdec patch failed"
fi

if [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    echoSection "FFmpeg PGO Step 1: Build Instrumented Binary"
    # Clean first to be sure
    # make distclean might be needed if issues occur
    export CFLAGS="$FF_FLAGS -fprofile-generate"
    export LDFLAGS="$FF_FLAGS -fprofile-generate"
    ./configure $CONFIGURE_ARGS
    checkStatus $? "PGO configure (generate) failed"
    make -j $CPUS
    checkStatus $? "PGO build (generate) failed"

    echoSection "FFmpeg PGO Step 2: Training Run"
    # Check if sample files exist
    if [ ! -d "$SAMPLE_DIR" ] || [ -z "$(ls -A "$SAMPLE_DIR"/*.{y4m.xz,266,mp4} 2>/dev/null)" ]; then
         echo "Warning: Sample directory '$SAMPLE_DIR' is empty or does not contain expected files. Skipping FFmpeg PGO training."
         ENABLE_FFMPEG_PGO="NO" # Fallback to non-PGO build
    else
        echo "Running training commands (may take a while)..."
        # --- Add representative training commands here ---
        # Example 1: Transcode using x264 (common use case)
        ./ffmpeg -y -i "$SAMPLE_DIR/stefan_sif.y4m.xz" -an -frames:v 30 -c:v libx264 -preset fast -f null -
        checkStatus $? "PGO training run 1 failed"
        # Example 2: Transcode using x265
        ./ffmpeg -y -i "$SAMPLE_DIR/taikotemoto.y4m.xz" -an -frames:v 30 -c:v libx265 -preset fast -f null -
        checkStatus $? "PGO training run 2 failed"
        # Example 3: Remuxing
        # ./ffmpeg -y -i "$SAMPLE_DIR/some_video.mp4" -c copy -f null -
        # Example 4: Decoding (if applicable)
        # ./ffmpeg -y -i "$SAMPLE_DIR/some_video.mp4" -f null -
        # Add more diverse commands based on expected usage
        # --- End of training commands ---

        echoSection "FFmpeg PGO Step 3: Merge Profile Data"
        # GCC >= 9 often doesn't require explicit merging for PGO
        # If using older GCC, you might need 'gcov-tool merge *.gcda' or similar
        echo "GCC PGO profile data generated in build directory (.gcda files)."
        # No explicit merge command needed for GCC 13.3 usually
    fi
fi

# Need to clean and re-configure for the final build (either PGO-Use or non-PGO)
echoSection "Cleaning before final FFmpeg build"
make clean
checkStatus $? "make clean failed"

if [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    echoSection "FFmpeg PGO Step 4: Configure Optimized Binary"
    export CFLAGS="$FF_FLAGS -fprofile-use -Wno-missing-profile" # Add -Wno-missing-profile for robustness
    export LDFLAGS="$FF_FLAGS -fprofile-use -Wno-missing-profile"
else
    echoSection "Configure FFmpeg (No PGO or PGO Skipped)"
    export CFLAGS="$FF_FLAGS"
    export LDFLAGS="$FF_FLAGS"
fi

# --pkg-config-flags="--static" is required to respect the Libs.private flags of the *.pc files
./configure $CONFIGURE_ARGS
checkStatus $? "configuration failed"

# start build
echoSection "FFmpeg Final Build"
make -j $CPUS
checkStatus $? "build failed"

# install ffmpeg
echoSection "FFmpeg Install"
make install
checkStatus $? "installation failed"