#!/bin/bash

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
echo "FFmpeg build arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
OUT_DIR=$4
CPUS=$5
FFMPEG_SNAPSHOT=$6
SKIP_VVDEC_PATCH=$7
FFMPEG_LIB_FLAGS=$8
ENABLE_FFMPEG_PGO=$9
OS_NAME=${10} # Passed from main build script

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- Version ---
FFMPEG_TARBALL_URL=""
if [ "$FFMPEG_SNAPSHOT" = "YES" ]; then
    VERSION="snapshot"
    # Use snapshot URL - ensure correct format
    FFMPEG_TARBALL_URL="https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2"
else
    # Fetch latest FFmpeg release version from GitHub API
    echo "Fetching latest FFmpeg release version from GitHub..."
    LATEST_FFMPEG_TAG=$(curl -s https://api.github.com/repos/FFmpeg/FFmpeg/releases/latest | jq -r '.tag_name')
    checkStatus $? "Failed to fetch latest FFmpeg release tag"
    # Remove 'n' prefix (e.g. n6.0 -> 6.0)
    VERSION=$(echo "$LATEST_FFMPEG_TAG" | sed 's/^n//')
    checkStatus $? "Failed to parse FFmpeg version from tag"
    echo "Latest FFmpeg version: $VERSION"
    FFMPEG_TARBALL_URL="https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.bz2"
fi
echo "FFmpeg version: $VERSION"

# --- Start in working directory ---
cd "$SOURCE_DIR"
checkStatus $? "change directory to SOURCE_DIR failed"
# Ensure ffmpeg source dir exists before cd'ing (might be cleaned by build.sh)
mkdir -p "ffmpeg"
cd "ffmpeg/"
checkStatus $? "change directory to source/ffmpeg failed"

# --- Download and Unpack FFmpeg Source ---
FFMPEG_SOURCE_SUBDIR="ffmpeg-src" # Use a dedicated subdirectory
if [ ! -d "$FFMPEG_SOURCE_SUBDIR" ] || [ -z "$(ls -A "$FFMPEG_SOURCE_SUBDIR")" ]; then
    echo "Downloading FFmpeg source from $FFMPEG_TARBALL_URL..."
    FFMPEG_TARBALL="ffmpeg-$VERSION.tar.bz2"
    if [ "$VERSION" = "snapshot" ]; then
        FFMPEG_TARBALL="ffmpeg-snapshot.tar.bz2"
    fi
    download "$FFMPEG_TARBALL_URL" "$FFMPEG_TARBALL"
    checkStatus $? "ffmpeg download failed"

    # unpack ffmpeg
    mkdir -p "$FFMPEG_SOURCE_SUBDIR"
    checkStatus $? "create directory $FFMPEG_SOURCE_SUBDIR failed"
    echo "Unpacking $FFMPEG_TARBALL..."
    tar -xjf "$FFMPEG_TARBALL" -C "$FFMPEG_SOURCE_SUBDIR" --strip-components=1
    checkStatus $? "unpack failed (tar -xjf)"
    # Clean up tarball
    rm "$FFMPEG_TARBALL"
else
    echo "Using existing FFmpeg source directory: $FFMPEG_SOURCE_SUBDIR"
fi

cd "$FFMPEG_SOURCE_SUBDIR/"
checkStatus $? "change directory to $FFMPEG_SOURCE_SUBDIR failed"

# --- Define directories and files for PGO ---
SAMPLE_DIR="$SCRIPT_DIR/../sample" # Assuming samples are here relative to script dir

# --- Prepare Build ---
EXTRA_VERSION="MiKayule-Group-$(date +%Y%m%d)" # Add date to version
# Base flags inherited from build.sh: CFLAGS, CXXFLAGS, CPPFLAGS, LDFLAGS, PKG_CONFIG_PATH

# --- Common Configure Arguments ---
CONFIGURE_ARGS="--prefix=\"$OUT_DIR\" --pkg-config-flags=--static --disable-static --enable-shared --enable-lto --extra-version=\"$EXTRA_VERSION\" --enable-gray"
# Add flags passed from main script (includes lib enables, gpl, nonfree, etc.)
CONFIGURE_ARGS="$CONFIGURE_ARGS $FFMPEG_LIB_FLAGS"

# --- Apply vvdec patch and fixes ---
if [ "$SKIP_VVDEC_PATCH" = "NO" ]; then
    PATCH_FILENAME="libvvdec.patch"
    PATCH_URL="https://raw.githubusercontent.com/wiki/fraunhoferhhi/vvdec/data/patch/v6-0001-avcodec-add-external-dec-libvvdec-for-H266-VVC.patch"
    if [ ! -f $PATCH_FILENAME ]; then
        echo "Downloading vvdec patch from $PATCH_URL..."
        # Use gh-proxy if needed in specific environments
        # wget -O $PATCH_FILENAME https://gh-proxy.com/$PATCH_URL
        wget -O $PATCH_FILENAME "$PATCH_URL"
        checkStatus $? "download vvdec patch failed"
    else
        echo "Using existing vvdec patch file ($PATCH_FILENAME)."
    fi

    echo "Applying vvdec patch..."
    # Use --forward to try applying even if some hunks are already applied
    patch --forward -p 1 < $PATCH_FILENAME
    PATCH_EXIT_CODE=$?
    if [ $PATCH_EXIT_CODE -ne 0 ] && [ $PATCH_EXIT_CODE -ne 1 ]; then
         echo "Warning: vvdec patch application possibly failed (Exit code: $PATCH_EXIT_CODE). Check patch output above. Continuing..."
         # Optionally exit here if patch must succeed: exit 1
    elif [ $PATCH_EXIT_CODE -eq 1 ]; then
         echo "Info: vvdec patch applied, some hunks might have been already applied."
    else
         echo "vvdec patch applied successfully."
    fi

    echo "Applying fix for vvdec profile constants in libavcodec/libvvdec.c"
    VVDEC_SRC_FILE="libavcodec/libvvdec.c"
    if [ -f $VVDEC_SRC_FILE ]; then
        # Use the run_sed helper function from functions.sh
        run_sed 's/FF_PROFILE_VVC_MAIN_10/AV_PROFILE_VVC_MAIN_10/g' "$VVDEC_SRC_FILE"
        run_sed 's/FF_PROFILE_VVC_MAIN_10_444/AV_PROFILE_VVC_MAIN_10_444/g' "$VVDEC_SRC_FILE"
    else
        echo "Warning: $VVDEC_SRC_FILE not found, skipping profile constant fix."
    fi
else
    echo "Skipping vvdec patch."
fi
# --- End vvdec patch and fixes ---

# --- PGO Handling ---

# Store original build flags from build.sh before potentially modifying them
ORIGINAL_CFLAGS="${CFLAGS}"
ORIGINAL_CXXFLAGS="${CXXFLAGS}"
ORIGINAL_LDFLAGS="${LDFLAGS}"
ORIGINAL_CPPFLAGS="${CPPFLAGS}"
ORIGINAL_PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
# Store original LD_LIBRARY_PATH too, if it exists
ORIGINAL_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"


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
    echo "DEBUG: CONFIGURE_ARGS=${CONFIGURE_ARGS}"
    echo "DEBUG: CFLAGS=${CFLAGS}"
    echo "DEBUG: CPPFLAGS=${CPPFLAGS}"
    echo "DEBUG: CXXFLAGS=${CXXFLAGS}"
    echo "DEBUG: LDFLAGS=${LDFLAGS}"
    echo "DEBUG: PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
    # --- End Debug Output ---

    ./configure $CONFIGURE_ARGS # Configure using base flags
    checkStatus $? "PGO configure (generate) failed. Check ffbuild/config.log"

    # NOW add PGO generate flags before running make
    PGO_GEN_CFLAGS=""
    PGO_GEN_LDFLAGS=""
    if [ "$OS_NAME" = "Darwin" ]; then
        # Clang flags - Ensure clang supports this syntax
        PGO_GEN_CFLAGS="-fprofile-instr-generate"
        PGO_GEN_LDFLAGS="-fprofile-instr-generate"
        echo "Adding Clang PGO generate flags..."
    else # Linux (GCC)
        PGO_GEN_CFLAGS="-fprofile-generate"
        PGO_GEN_LDFLAGS="-fprofile-generate -lgcov" # Link gcov for GCC PGO
        echo "Adding GCC PGO generate flags..."
    fi
    export CFLAGS="${ORIGINAL_CFLAGS} ${PGO_GEN_CFLAGS}"
    export CXXFLAGS="${ORIGINAL_CXXFLAGS} ${PGO_GEN_CFLAGS}"
    export LDFLAGS="${ORIGINAL_LDFLAGS} ${PGO_GEN_LDFLAGS}"
    echo "DEBUG: CFLAGS for PGO generate make: ${CFLAGS}"
    echo "DEBUG: LDFLAGS for PGO generate make: ${LDFLAGS}"

    make -j $CPUS
    checkStatus $? "PGO build (generate) failed"

    echoSection "FFmpeg PGO Step 2: Training Run"
    # Check if sample files exist
    if [ ! -d "$SAMPLE_DIR" ] || [ -z "$(find "$SAMPLE_DIR" -maxdepth 1 \( -name '*.y4m.xz' -o -name '*.mp4' \) -print -quit)" ]; then
         echo "Warning: Sample directory '$SAMPLE_DIR' does not exist or does not contain expected files (*.y4m.xz, *.mp4). Skipping FFmpeg PGO training."
         ENABLE_FFMPEG_PGO="NO_TRAINING_DATA" # Use a specific state
    else
        # --- Set LD_LIBRARY_PATH for Training Run ---
        echo "Setting library path for PGO training run..."
        # Add current build directory and potentially lib directories from TOOL_DIR
        FFMPEG_BUILD_LIBS_PATH="$(pwd):${TOOL_DIR}/lib"
        if [ "$OS_NAME" = "Linux" ]; then
             FFMPEG_BUILD_LIBS_PATH="$FFMPEG_BUILD_LIBS_PATH:${TOOL_DIR}/lib64"
        fi
        export LD_LIBRARY_PATH="${FFMPEG_BUILD_LIBS_PATH}:${ORIGINAL_LD_LIBRARY_PATH}"
         # On macOS, DYLD_LIBRARY_PATH is often needed instead of/in addition to LD_LIBRARY_PATH
        if [ "$OS_NAME" = "Darwin" ]; then
            export DYLD_LIBRARY_PATH="${FFMPEG_BUILD_LIBS_PATH}:${DYLD_LIBRARY_PATH}"
            echo "DEBUG: DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}"
        fi
        echo "DEBUG: LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
        # --- End LD_LIBRARY_PATH Setting ---

        echo "Running training commands (may take a while)..."
        # Simple training examples: Encode first 30 frames of samples
        if [ -f "$SAMPLE_DIR/stefan_sif.y4m.xz" ]; then
            echo "Running training command 1 (x264)..."
            xz -dc "$SAMPLE_DIR/stefan_sif.y4m.xz" | ./ffmpeg -y -f yuv4mpegpipe -i - -an -frames:v 30 -c:v libx264 -preset fast -f null -
            checkStatus $? "PGO training run 1 (x264) failed"
        else echo "Skipping training 1: stefan_sif.y4m.xz not found"; fi

        if [ -f "$SAMPLE_DIR/taikotemoto.y4m.xz" ]; then
            echo "Running training command 2 (x265)..."
            xz -dc "$SAMPLE_DIR/taikotemoto.y4m.xz" | ./ffmpeg -y -f yuv4mpegpipe -i - -an -frames:v 30 -c:v libx265 -preset fast -f null -
            checkStatus $? "PGO training run 2 (x265) failed"
        else echo "Skipping training 2: taikotemoto.y4m.xz not found"; fi

        # Add more diverse training commands if needed
        # e.g., decoding, transcoding, filter usage
        # if [ -f "$SAMPLE_DIR/test.mp4" ]; then
        #    echo "Running training command 3 (decode)..."
        #    ./ffmpeg -y -i "$SAMPLE_DIR/test.mp4" -t 5 -f null -
        #    checkStatus $? "PGO training run 3 (decode) failed"
        # fi

        echoSection "FFmpeg PGO Step 3: Process Profile Data"
        if [ "$OS_NAME" = "Darwin" ]; then
            # Find llvm-profdata (might be in Xcode toolchain)
            LLVM_PROFDATA_CMD=""
            if command -v llvm-profdata >/dev/null 2>&1; then
                LLVM_PROFDATA_CMD="llvm-profdata"
            else
                # Try finding it via xcode-select
                XCODE_TOOLCHAIN_PATH=$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin
                if [ -x "$XCODE_TOOLCHAIN_PATH/llvm-profdata" ]; then
                    LLVM_PROFDATA_CMD="$XCODE_TOOLCHAIN_PATH/llvm-profdata"
                else
                    echo "ERROR: llvm-profdata not found. Cannot merge PGO profiles on macOS."
                    exit 1
                fi
            fi
            echo "Merging Clang PGO profiles using: $LLVM_PROFDATA_CMD"
            # Find .profraw files (usually in the build root)
            $LLVM_PROFDATA_CMD merge -o default.profdata ./*.profraw
            checkStatus $? "llvm-profdata merge failed"
            # Clean up raw profiles
            rm -f ./*.profraw
        else # Linux (GCC)
            echo "GCC PGO profile data (.gcda files) generated in build directory."
            # Merging is usually automatic with GCC, no explicit step needed here
            # Ensure objects are linked correctly in the 'use' phase.
        fi

        # --- Restore Library Paths ---
        export LD_LIBRARY_PATH="${ORIGINAL_LD_LIBRARY_PATH}"
        if [ "$OS_NAME" = "Darwin" ]; then
             export DYLD_LIBRARY_PATH="${ORIGINAL_DYLD_LIBRARY_PATH}"
        fi
        echo "DEBUG: Restored library paths"
        # --- End Restore ---

    fi # End check for sample dir

    # Need to clean and re-configure for the final build
    echoSection "Cleaning before final optimized FFmpeg build"
    make clean
    checkStatus $? "make clean failed"

    # Check if training actually happened before setting PGO-use flags
    if [ "$ENABLE_FFMPEG_PGO" = "NO_TRAINING_DATA" ]; then
        echo "PGO 'use' phase skipped because training data was missing."
        # Use original flags for final configure
        export CFLAGS="${ORIGINAL_CFLAGS}"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
        export LDFLAGS="${ORIGINAL_LDFLAGS}"
        export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
        export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"
        ENABLE_FFMPEG_PGO="NO" # Ensure final make doesn't use PGO flags
    else
        # Configure again using ORIGINAL flags before adding PGO-use flags for make
        echoSection "FFmpeg PGO Step 4: Configure Optimized Binary"
        export CFLAGS="${ORIGINAL_CFLAGS}"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
        export LDFLAGS="${ORIGINAL_LDFLAGS}"
        export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
        export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"

        echo "DEBUG: Running final configure (PGO use phase) with base flags..."
        ./configure $CONFIGURE_ARGS
        checkStatus $? "PGO configure (use) failed. Check ffbuild/config.log"

        # NOW add PGO-use flags before final make
        PGO_USE_CFLAGS=""
        PGO_USE_LDFLAGS=""
        if [ "$OS_NAME" = "Darwin" ]; then
            PGO_USE_CFLAGS="-fprofile-instr-use=default.profdata"
            PGO_USE_LDFLAGS="-fprofile-instr-use=default.profdata"
            echo "Adding Clang PGO use flags..."
        else # Linux (GCC)
            PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile" # -Wno suppresses warnings if not all code was trained
            PGO_USE_LDFLAGS="-fprofile-use -Wno-missing-profile"
            echo "Adding GCC PGO use flags..."
        fi
        export CFLAGS="${ORIGINAL_CFLAGS} ${PGO_USE_CFLAGS}"
        export CXXFLAGS="${ORIGINAL_CXXFLAGS} ${PGO_USE_CFLAGS}" # Use CFLAGS for C++ too
        export LDFLAGS="${ORIGINAL_LDFLAGS} ${PGO_USE_LDFLAGS}"
        echo "DEBUG: CFLAGS for final optimized make: ${CFLAGS}"
        echo "DEBUG: LDFLAGS for final optimized make: ${LDFLAGS}"
        # Fall through to final make below
    fi # End check for NO_TRAINING_DATA

# End of IF ENABLE_FFMPEG_PGO=YES block / Start of NO PGO block
else # PGO Disabled
    echoSection "Configure FFmpeg (PGO Disabled)"
    # Use original flags inherited from build.sh
    export CFLAGS="${ORIGINAL_CFLAGS}"
    export CXXFLAGS="${ORIGINAL_CXXFLAGS}"
    export LDFLAGS="${ORIGINAL_LDFLAGS}"
    export CPPFLAGS="${ORIGINAL_CPPFLAGS}"
    export PKG_CONFIG_PATH="${ORIGINAL_PKG_CONFIG_PATH}"

    # Configure for the final non-PGO build
    echo "DEBUG: Running final configure (No PGO) with:"
    echo "DEBUG: CONFIGURE_ARGS=${CONFIGURE_ARGS}"
    echo "DEBUG: CFLAGS=${CFLAGS}"
    echo "DEBUG: CPPFLAGS=${CPPFLAGS}"
    echo "DEBUG: CXXFLAGS=${CXXFLAGS}"
    echo "DEBUG: LDFLAGS=${LDFLAGS}"
    echo "DEBUG: PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"

    ./configure $CONFIGURE_ARGS
    checkStatus $? "configuration failed. Check ffbuild/config.log"
    # Fall through to final make below (no PGO flags needed)
fi


# --- Final Build ---
echoSection "FFmpeg Final Build"
# Make will use the CFLAGS/LDFLAGS currently exported (either PGO-use or non-PGO)
make -j $CPUS
checkStatus $? "Final build failed"

# --- Install ---
echoSection "FFmpeg Install"
make install
checkStatus $? "Installation failed"

# --- Restore original environment? Usually not needed as script exits ---
# export CFLAGS="${ORIGINAL_CFLAGS}"
# ... etc ...
# export LD_LIBRARY_PATH="${ORIGINAL_LD_LIBRARY_PATH}"
# if [ "$OS_NAME" = "Darwin" ]; then export DYLD_LIBRARY_PATH="${ORIGINAL_DYLD_LIBRARY_PATH}"; fi

echo "FFmpeg build script finished in $(pwd)"