#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
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
# Ensure ffmpeg source dir exists before cd'ing (might be cleaned by build.sh)
mkdir -p "ffmpeg"
cd "ffmpeg/"
checkStatus $? "change directory failed"

# download ffmpeg source (Only if ffmpeg dir doesn't exist or is empty after potential cleaning)
FFMPEG_SOURCE_DIR="ffmpeg" # Relative path after cd ffmpeg/
if [ ! -d "$FFMPEG_SOURCE_DIR" ] || [ -z "$(ls -A $FFMPEG_SOURCE_DIR)" ]; then
    echo "Downloading FFmpeg source..."
    download https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.bz2 "ffmpeg.tar.bz2"
    checkStatus $? "ffmpeg download failed"

    # unpack ffmpeg
    mkdir -p "$FFMPEG_SOURCE_DIR" # Use -p
    checkStatus $? "create directory failed"
    bunzip2 "ffmpeg.tar.bz2"
    checkStatus $? "unpack failed (bunzip2)"
    tar -xf ffmpeg.tar -C "$FFMPEG_SOURCE_DIR" --strip-components=1
    checkStatus $? "unpack failed (tar)"
else
    echo "Using existing FFmpeg source directory."
fi

cd "$FFMPEG_SOURCE_DIR/"
checkStatus $? "change directory to ffmpeg source failed"


# Define directories and files
SAMPLE_DIR="$SCRIPT_DIR/../sample" # Assuming samples are here

# prepare build
EXTRA_VERSION="MiKayule-Group"
# Base flags inherited from build.sh: CFLAGS, CXXFLAGS, CPPFLAGS, LDFLAGS, PKG_CONFIG_PATH

# Common configure arguments
# Fixed --pkg-config-flags syntax
CONFIGURE_ARGS="--prefix=\"$OUT_DIR\" --pkg-config-flags=--static --disable-static --enable-shared --enable-lto --extra-version=\"$EXTRA_VERSION\" --enable-gray --enable-libxml2 $FFMPEG_LIB_FLAGS"

# --- Apply vvdec patch and fixes ---
if [ $SKIP_VVDEC_PATCH = "NO" ]; then
    PATCH_FILENAME="libvvdec.patch"
    if [ ! -f $PATCH_FILENAME ]; then
        echo "Downloading vvdec patch..."
        wget -O $PATCH_FILENAME https://gh-proxy.com/https://raw.githubusercontent.com/wiki/fraunhoferhhi/vvdec/data/patch/v6-0001-avcodec-add-external-dec-libvvdec-for-H266-VVC.patch
        checkStatus $? "download vvdec patch failed"
    else
        echo "Using existing vvdec patch file ($PATCH_FILENAME)."
    fi

    echo "Applying vvdec patch..."
    patch --forward -p 1 < $PATCH_FILENAME
    PATCH_EXIT_CODE=$?
    if [ $PATCH_EXIT_CODE -ne 0 ] && [ $PATCH_EXIT_CODE -ne 1 ]; then
         echo "Warning: vvdec patch application possibly failed (Exit code: $PATCH_EXIT_CODE). Continuing..."
    elif [ $PATCH_EXIT_CODE -eq 1 ]; then
         echo "Info: vvdec patch hunks might have been already applied."
    else
         echo "vvdec patch applied successfully."
    fi

    echo "Applying fix for vvdec profile constants in libavcodec/libvvdec.c"
    VVDEC_SRC_FILE="libavcodec/libvvdec.c"
    if [ -f $VVDEC_SRC_FILE ]; then
        sed -i 's/FF_PROFILE_VVC_MAIN_10/AV_PROFILE_VVC_MAIN_10/g' $VVDEC_SRC_FILE
        checkStatus $? "sed fix for FF_PROFILE_VVC_MAIN_10 failed"
        sed -i 's/FF_PROFILE_VVC_MAIN_10_444/AV_PROFILE_VVC_MAIN_10_444/g' $VVDEC_SRC_FILE
        checkStatus $? "sed fix for FF_PROFILE_VVC_MAIN_10_444 failed"
    else
        echo "Warning: $VVDEC_SRC_FILE not found, skipping sed fix."
    fi
else
    echo "Skipping vvdec patch."
fi
# --- End vvdec patch and fixes ---

# --- Start PGO / Configure ---
# Store original flags from build.sh before potentially modifying them
ORIGINAL_CFLAGS="${CFLAGS}"
ORIGINAL_CXXFLAGS="${CXXFLAGS}"
ORIGINAL_LDFLAGS="${LDFLAGS}"
ORIGINAL_CPPFLAGS="${CPPFLAGS}"
ORIGINAL_PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"

if [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    echoSection "FFmpeg PGO Step 1: Configure for Instrumented Binary"
    # Use ORIGINAL flags (with -I, -L, -fPIC) for configure ONLY
    export CFLAGS="${ORIGINAL_CFLAGS}"
    export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
    export LDFLAGS="${ORIGINAL_LDFLAGS}"
    export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
    export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"

    # --- Add Debug Output ---
    echo "DEBUG: Running PGO generate configure with:"
    echo "DEBUG: CFLAGS=${CFLAGS}"
    echo "DEBUG: CPPFLAGS=${CPPFLAGS}"
    echo "DEBUG: CXXFLAGS=${CXXFLAGS}"
    echo "DEBUG: LDFLAGS=${LDFLAGS}"
    echo "DEBUG: PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
    # --- End Debug Output ---

    ./configure $CONFIGURE_ARGS # Configure using base flags
    checkStatus $? "PGO configure (generate) failed" # Rename this check maybe? Configure didn't fail *because* of PGO flags yet.

    # NOW add PGO flags before running make for the instrumented build
    echo "Adding -fprofile-generate flags for PGO build..."
    export CFLAGS="${ORIGINAL_CFLAGS} -fprofile-generate"
    export CXXFLAGS="${ORIGINAL_CXXFLAGS} -fprofile-generate"
    # Add -fprofile-generate to LDFLAGS? Needed for LTO linking during make.
    export LDFLAGS="${ORIGINAL_LDFLAGS} -fprofile-generate"
    echo "DEBUG: CFLAGS for PGO generate make: ${CFLAGS}"
    echo "DEBUG: LDFLAGS for PGO generate make: ${LDFLAGS}"

    make -j $CPUS # Build with PGO flags
    checkStatus $? "PGO build (generate) failed"

    echoSection "FFmpeg PGO Step 2: Training Run"
    # Check if sample files exist
    if [ ! -d "$SAMPLE_DIR" ] || [ -z "$(ls -A "$SAMPLE_DIR"/*.{y4m.xz,266,mp4} 2>/dev/null)" ]; then
         echo "Warning: Sample directory '$SAMPLE_DIR' is empty or does not contain expected files (*.y4m.xz, *.266, *.mp4). Skipping FFmpeg PGO training."
         ENABLE_FFMPEG_PGO="NO_TRAINING_DATA" # Use a specific state instead of just NO
    else
        echo "Running training commands (may take a while)..."
        # --- Add representative training commands here ---
        ./ffmpeg -y -i "$SAMPLE_DIR/stefan_sif.y4m.xz" -an -frames:v 30 -c:v libx264 -preset fast -f null -
        checkStatus $? "PGO training run 1 failed"
        ./ffmpeg -y -i "$SAMPLE_DIR/taikotemoto.y4m.xz" -an -frames:v 30 -c:v libx265 -preset fast -f null -
        checkStatus $? "PGO training run 2 failed"
        # --- End of training commands ---

        echoSection "FFmpeg PGO Step 3: Merge Profile Data"
        echo "GCC PGO profile data generated in build directory (.gcda files)."
    fi # End check for sample dir

    # Need to clean and re-configure for the final build (either PGO-Use or non-PGO)
    echoSection "Cleaning before final FFmpeg build"
    make clean
    checkStatus $? "make clean failed"

    # Check if training actually happened before setting PGO-use flags
    if [ "$ENABLE_FFMPEG_PGO" = "NO_TRAINING_DATA" ]; then
        echo "PGO 'use' phase skipped because training data was missing."
        # Flags will be set to non-PGO below
        export CFLAGS="${ORIGINAL_CFLAGS}"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
        export LDFLAGS="${ORIGINAL_LDFLAGS}"
        export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
        export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"
        # Set state to NO to match the final configure block logic
        ENABLE_FFMPEG_PGO="NO"
    else
        # Configure again using ORIGINAL flags before adding PGO-use flags for make
        echoSection "FFmpeg PGO Step 4: Configure Optimized Binary"
        export CFLAGS="${ORIGINAL_CFLAGS}"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
        export LDFLAGS="${ORIGINAL_LDFLAGS}"
        export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
        export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"

        echo "DEBUG: Running final configure (PGO use phase) with:"
        echo "DEBUG: CFLAGS=${CFLAGS}"
        # ... Add other debug echos if needed ...
        ./configure $CONFIGURE_ARGS
        checkStatus $? "PGO configure (use) failed"

        # NOW add PGO-use flags before final make
        echo "Adding -fprofile-use flags for PGO optimized build..."
        export CFLAGS="${ORIGINAL_CFLAGS} -fprofile-use -Wno-missing-profile"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS} -fprofile-use -Wno-missing-profile"
        export LDFLAGS="${ORIGINAL_LDFLAGS} -fprofile-use -Wno-missing-profile"
        echo "DEBUG: CFLAGS for final make: ${CFLAGS}"
        echo "DEBUG: LDFLAGS for final make: ${LDFLAGS}"
        # Fall through to final make below
    fi

# End of IF ENABLE_FFMPEG_PGO=YES block / Start of NO PGO block
elif [ "$ENABLE_FFMPEG_PGO" = "NO" ]; then
    echoSection "Configure FFmpeg (PGO Disabled or Skipped)"
    # Use original flags inherited from build.sh
    export CFLAGS="${ORIGINAL_CFLAGS}"
    export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
    export LDFLAGS="${ORIGINAL_LDFLAGS}"
    export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
    export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"

    # Clean only if skipping PGO after failed training data check
    if [ "$ENABLE_FFMPEG_PGO" = "NO_TRAINING_DATA" ]; then # Check the original request state
         make clean
         checkStatus $? "make clean failed (PGO skipped)"
    fi

    # Configure for the final non-PGO build
    echo "DEBUG: Running final configure (No PGO) with:"
    echo "DEBUG: CFLAGS=${CFLAGS}"
    # ... Add other debug echos if needed ...
    ./configure $CONFIGURE_ARGS
    checkStatus $? "configuration failed"
    # Fall through to final make below (no PGO flags needed)
fi


# start build
echoSection "FFmpeg Final Build"
# Make will use the CFLAGS/LDFLAGS currently exported (either PGO-use or non-PGO)
make -j $CPUS
checkStatus $? "build failed"

# install ffmpeg
echoSection "FFmpeg Install"
make install
checkStatus $? "installation failed"

# Restore original flags? Not necessary as script exits.