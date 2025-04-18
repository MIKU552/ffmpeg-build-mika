#!/bin/bash

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

# Force GCC compiler (or keep LLVM if preferred, ensure consistency)
export CC=gcc
export CXX=g++
export AR=ar
export NM=nm
export RANLIB=ranlib
export LD=ld
echo "Using GCC: CC=$CC, CXX=$CXX, AR=$AR, NM=$NM, RANLIB=$RANLIB, LD=$LD"

# --- Argument Parsing ---
SKIP_BUNDLE="YES"
SKIP_TEST="NO"
SKIP_LIBBLURAY="NO"
SKIP_SNAPPY="NO"
SKIP_SRT="NO"
SKIP_LIBVMAF="NO"
SKIP_ZIMG="NO"
SKIP_ZVBI="NO"
SKIP_AOM="NO"
SKIP_DAV1D="NO"
SKIP_OPEN_H264="NO"
SKIP_OPEN_JPEG="NO"
SKIP_RAV1E="NO"
SKIP_SVT_AV1="NO"
SKIP_LIBTHEORA="NO"
SKIP_VPX="NO"
SKIP_LIBWEBP="NO"
SKIP_X264="NO"
SKIP_X265="NO"
SKIP_X265_MULTIBIT="NO"
SKIP_LAME="NO"
SKIP_OPUS="NO"
SKIP_LIBVORBIS="NO"
SKIP_LIBKLVANC="NO"
SKIP_DECKLINK="YES"
SKIP_VVDEC="NO"
SKIP_VVENC="NO"
# --- Add skips for tools/base libs if needed (e.g., SKIP_NASM, SKIP_CMAKE, SKIP_OPENSSL etc.) ---
SKIP_NASM="NO"
SKIP_PKG_CONFIG="NO"
SKIP_ZLIB="NO"
SKIP_OPENSSL="NO"
SKIP_CMAKE="NO"
SKIP_NINJA="NO"
SKIP_LIBXML2="NO"
SKIP_FRIBIDI="NO"
SKIP_FREETYPE="NO"
SKIP_FONTCONFIG="NO"
SKIP_HARFBUZZ="NO"
SKIP_SDL="NO"
SKIP_LIBASS="NO"
SKIP_LIBOGG="NO"
# --- End tool skips ---
DECKLINK_SDK=""
ENABLE_FFMPEG_PGO="YES"
FFMPEG_SNAPSHOT="YES"
CPU_LIMIT=""
FORCE_REBUILD="NO"

for arg in "$@"; do
    KEY=${arg%%=*}
    VALUE=${arg#*\=}
    # --- Add parsing for tool skips ---
    if [ $KEY = "-SKIP_NASM" ]; then SKIP_NASM=$VALUE; echo "skip nasm $VALUE"; fi
    if [ $KEY = "-SKIP_PKG_CONFIG" ]; then SKIP_PKG_CONFIG=$VALUE; echo "skip pkg-config $VALUE"; fi
    if [ $KEY = "-SKIP_ZLIB" ]; then SKIP_ZLIB=$VALUE; echo "skip zlib $VALUE"; fi
    if [ $KEY = "-SKIP_OPENSSL" ]; then SKIP_OPENSSL=$VALUE; echo "skip openssl $VALUE"; fi
    if [ $KEY = "-SKIP_CMAKE" ]; then SKIP_CMAKE=$VALUE; echo "skip cmake $VALUE"; fi
    if [ $KEY = "-SKIP_NINJA" ]; then SKIP_NINJA=$VALUE; echo "skip ninja $VALUE"; fi
    if [ $KEY = "-SKIP_LIBXML2" ]; then SKIP_LIBXML2=$VALUE; echo "skip libxml2 $VALUE"; fi
    if [ $KEY = "-SKIP_FRIBIDI" ]; then SKIP_FRIBIDI=$VALUE; echo "skip fribidi $VALUE"; fi
    if [ $KEY = "-SKIP_FREETYPE" ]; then SKIP_FREETYPE=$VALUE; echo "skip freetype $VALUE"; fi
    if [ $KEY = "-SKIP_FONTCONFIG" ]; then SKIP_FONTCONFIG=$VALUE; echo "skip fontconfig $VALUE"; fi
    if [ $KEY = "-SKIP_HARFBUZZ" ]; then SKIP_HARFBUZZ=$VALUE; echo "skip harfbuzz $VALUE"; fi
    if [ $KEY = "-SKIP_SDL" ]; then SKIP_SDL=$VALUE; echo "skip SDL $VALUE"; fi
    if [ $KEY = "-SKIP_LIBASS" ]; then SKIP_LIBASS=$VALUE; echo "skip libass $VALUE"; fi
    if [ $KEY = "-SKIP_LIBOGG" ]; then SKIP_LIBOGG=$VALUE; echo "skip libogg $VALUE"; fi
    # --- End tool skip parsing ---
    if [ $KEY = "-SKIP_BUNDLE" ]; then SKIP_BUNDLE=$VALUE; echo "skip bundle $VALUE"; fi
    if [ $KEY = "-SKIP_TEST" ]; then SKIP_TEST=$VALUE; echo "skip test $VALUE"; fi
    if [ $KEY = "-SKIP_LIBBLURAY" ]; then SKIP_LIBBLURAY=$VALUE; echo "skip libbluray $VALUE"; fi
    if [ $KEY = "-SKIP_SNAPPY" ]; then SKIP_SNAPPY=$VALUE; echo "skip snappy $VALUE"; fi
    if [ $KEY = "-SKIP_SRT" ]; then SKIP_SRT=$VALUE; echo "skip srt $VALUE"; fi
    if [ $KEY = "-SKIP_LIBVMAF" ]; then SKIP_LIBVMAF=$VALUE; echo "skip libvmaf $VALUE"; fi
    if [ $KEY = "-SKIP_ZIMG" ]; then SKIP_ZIMG=$VALUE; echo "skip zimg $VALUE"; fi
    if [ $KEY = "-SKIP_ZVBI" ]; then SKIP_ZVBI=$VALUE; echo "skip zvbi $VALUE"; fi
    if [ $KEY = "-SKIP_AOM" ]; then SKIP_AOM=$VALUE; echo "skip aom $VALUE"; fi
    if [ $KEY = "-SKIP_DAV1D" ]; then SKIP_DAV1D=$VALUE; echo "skip dav1d $VALUE"; fi
    if [ $KEY = "-SKIP_OPEN_H264" ]; then SKIP_OPEN_H264=$VALUE; echo "skip openh264 $VALUE"; fi
    if [ $KEY = "-SKIP_OPEN_JPEG" ]; then SKIP_OPEN_JPEG=$VALUE; echo "skip openJPEG $VALUE"; fi
    if [ $KEY = "-SKIP_RAV1E" ]; then SKIP_RAV1E=$VALUE; echo "skip rav1e $VALUE"; fi
    if [ $KEY = "-SKIP_SVT_AV1" ]; then SKIP_SVT_AV1=$VALUE; echo "skip svt-av1 $VALUE"; fi
    if [ $KEY = "-SKIP_LIBTHEORA" ]; then SKIP_LIBTHEORA=$VALUE; echo "skip libtheora $VALUE"; fi
    if [ $KEY = "-SKIP_VPX" ]; then SKIP_VPX=$VALUE; echo "skip vpx $VALUE"; fi
    if [ $KEY = "-SKIP_LIBWEBP" ]; then SKIP_LIBWEBP=$VALUE; echo "skip libwebp $VALUE"; fi
    if [ $KEY = "-SKIP_X264" ]; then SKIP_X264=$VALUE; echo "skip x264 $VALUE"; fi
    if [ $KEY = "-SKIP_X265" ]; then SKIP_X265=$VALUE; echo "skip x265 $VALUE"; fi
    if [ $KEY = "-SKIP_X265_MULTIBIT" ]; then SKIP_X265_MULTIBIT=$VALUE; echo "skip x265 multibit $VALUE"; fi
    if [ $KEY = "-SKIP_LAME" ]; then SKIP_LAME=$VALUE; echo "skip lame (mp3) $VALUE"; fi
    if [ $KEY = "-SKIP_OPUS" ]; then SKIP_OPUS=$VALUE; echo "skip opus $VALUE"; fi
    if [ $KEY = "-SKIP_LIBVORBIS" ]; then SKIP_LIBVORBIS=$VALUE; echo "skip libvorbis $VALUE"; fi
    if [ $KEY = "-SKIP_LIBKLVANC" ]; then SKIP_LIBKLVANC=$VALUE; echo "skip libklvanc $VALUE"; fi
    if [ $KEY = "-SKIP_DECKLINK" ]; then SKIP_DECKLINK=$VALUE; echo "skip decklink $VALUE"; fi
    if [ $KEY = "-SKIP_VVDEC" ]; then SKIP_VVDEC=$VALUE; echo "skip vvdec $VALUE"; fi
    if [ $KEY = "-SKIP_VVENC" ]; then SKIP_VVENC=$VALUE; echo "skip vvenc $VALUE"; fi
    if [ $KEY = "-ENABLE_FFMPEG_PGO" ]; then ENABLE_FFMPEG_PGO=$VALUE; echo "enable ffmpeg pgo $VALUE"; fi
    if [ $KEY = "-DECKLINK_SDK" ]; then DECKLINK_SDK=$VALUE; echo "use decklink SDK folder $VALUE"; fi
    if [ $KEY = "-FFMPEG_SNAPSHOT" ]; then FFMPEG_SNAPSHOT=$VALUE; echo "use ffmpeg snapshot $VALUE"; fi
    if [ $KEY = "-CPU_LIMIT" ]; then CPU_LIMIT=$VALUE; echo "use cpu limit $VALUE"; fi
    if [ $KEY = "-FORCE_REBUILD" ]; then FORCE_REBUILD=$VALUE; echo "force rebuild $VALUE"; fi
done

# --- Directory Definitions ---
BASE_DIR="$( cd "$( dirname "$0" )" > /dev/null 2>&1 && pwd )"
echo "base directory is ${BASE_DIR}"
SCRIPT_DIR="${BASE_DIR}/script"
echo "script directory is ${SCRIPT_DIR}"
WORKING_DIR="$( pwd )"
echo "working directory is ${WORKING_DIR}"
SOURCE_DIR="$WORKING_DIR/source"
echo "source code directory is ${SOURCE_DIR}"
LOG_DIR="$WORKING_DIR/log"
echo "logs code directory is ${LOG_DIR}"
TOOL_DIR="$WORKING_DIR/tool"
echo "tool directory is ${TOOL_DIR}"
OUT_DIR="$WORKING_DIR/out"
echo "output directory is ${OUT_DIR}"
if [ $SKIP_TEST = "NO" ]; then
    TEST_DIR="${BASE_DIR}/test"
    echo "test directory is ${TEST_DIR}"
    TEST_OUT_DIR="$WORKING_DIR/test"
    echo "test output directory is ${TEST_OUT_DIR}"
fi

# --- Load Functions ---
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . $SCRIPT_DIR/functions.sh
else
    echo "ERROR: functions.sh not found in $SCRIPT_DIR"
    exit 1
fi


# --- Prepare Workspace ---
echoSection "prepare workspace"
mkdir -p "$SOURCE_DIR"
checkStatus $? "unable to create source code directory"
mkdir -p "$LOG_DIR"
checkStatus $? "unable to create logs directory"
mkdir -p "$TOOL_DIR"
checkStatus $? "unable to create tool directory"
mkdir -p "$TOOL_DIR/bin"
mkdir -p "$TOOL_DIR/lib"
mkdir -p "$TOOL_DIR/lib64" # Create lib64 just in case
mkdir -p "$TOOL_DIR/include"
mkdir -p "$TOOL_DIR/lib/pkgconfig"
mkdir -p "$TOOL_DIR/lib64/pkgconfig" # Create lib64/pkgconfig just in case
PATH="$TOOL_DIR/bin:$PATH" # Prepend TOOL_DIR/bin to PATH
mkdir -p "$OUT_DIR"
checkStatus $? "unable to create output directory"
if [ $SKIP_TEST = "NO" ]; then
    mkdir -p "$TEST_OUT_DIR"
    checkStatus $? "unable to create test output directory"
fi

# --- Setup Global Build Environment ---
echoSection "Setup Global Build Environment"
# Set environment variables globally for dependency builds, handling lib and lib64
echo "Exporting paths for build environment (with -fPIC, supporting lib and lib64):"
echo "  Include Path: ${TOOL_DIR}/include"
echo "  Library Path: ${TOOL_DIR}/lib and ${TOOL_DIR}/lib64"
echo "  PkgConfig Path: ${TOOL_DIR}/lib/pkgconfig and ${TOOL_DIR}/lib64/pkgconfig"

# Use direct assignment assuming external flags aren't needed/compatible
export CFLAGS="-I${TOOL_DIR}/include -fPIC"
export CPPFLAGS="-I${TOOL_DIR}/include -fPIC"
export CXXFLAGS="-I${TOOL_DIR}/include -fPIC"
# Add both lib and lib64 to LDFLAGS search path
export LDFLAGS="-L${TOOL_DIR}/lib -L${TOOL_DIR}/lib64"
# Add both lib and lib64 pkgconfig paths, keeping existing ones
export PKG_CONFIG_PATH="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/lib64/pkgconfig:${PKG_CONFIG_PATH}"

echo "CFLAGS=${CFLAGS}"
echo "CPPFLAGS=${CPPFLAGS}"
echo "CXXFLAGS=${CXXFLAGS}"
echo "LDFLAGS=${LDFLAGS}"
echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
echo "PATH=${PATH}"


# --- Force Rebuild Logic ---
if [ "$FORCE_REBUILD" = "YES" ]; then
    echoSection "Forcing rebuild, relevant target files will be ignored/overwritten"
    # No need to delete markers if checking files; cleaning source dir handled by run_build
fi


# --- Detect CPU Threads ---
CPUS=1
if [ "$CPU_LIMIT" != "" ]; then
    CPUS=$CPU_LIMIT
else
    CPUS_NPROC="$(nproc 2> /dev/null)"
    if [ $? -eq 0 ] && [ "$CPUS_NPROC" -gt 0 ]; then
        CPUS=$CPUS_NPROC
    else
        CPUS_SYSCTL="$(sysctl -n hw.ncpu 2> /dev/null)"
        if [ $? -eq 0 ] && [ "$CPUS_SYSCTL" -gt 0 ]; then
            CPUS=$CPUS_SYSCTL
        fi
    fi
fi
echo "Using ${CPUS} cpu threads"
echo "System info: $(uname -a)"
COMPILATION_START_TIME=$(currentTimeInSeconds)

# --- FFmpeg Build Configuration ---
FFMPEG_LIB_FLAGS=""
REQUIRES_GPL="NO"
REQUIRES_NON_FREE="NO"

# --- Build Dependencies ---

# Function to wrap build calls with skip logic (checking lib & lib64) and source cleaning
# Usage: run_build <libname> <script_name> <target_check_filename> <source_subdir> <ffmpeg_flag> <is_gpl> <is_nonfree> [extra_args...]
# target_check_filename: Can be lib/libfoo.a, bin/foo, or just foo if installed to bin
run_build() {
    local libname=$1
    local script_name=$2
    local target_check_filename=$3 # e.g., libz.a or nasm or pkg-config
    local source_subdir=$4         # e.g., zlib or nasm
    local ffmpeg_flag=$5
    local is_gpl=$6
    local is_nonfree=$7
    shift 7 # Remove first 7 args, rest are extra_args for build script
    local extra_args=("$@")

    # Determine potential paths based on target filename convention
    local target_path_lib="$TOOL_DIR/lib/$target_check_filename"
    local target_path_lib64="$TOOL_DIR/lib64/$target_check_filename"
    local target_path_bin="$TOOL_DIR/bin/$target_check_filename"
    local target_path_include="$TOOL_DIR/include/$target_check_filename" # For headers like decklink

    # Determine which path(s) to check primarily
    local check_paths=()
    local found_path=""
    if [[ "$libname" == "nasm" || "$libname" == "cmake" || "$libname" == "ninja" || "$libname" == "pkg-config" ]]; then
        check_paths+=("$target_path_bin")
    elif [[ "$libname" == "decklink" ]]; then
        # Decklink installs headers, check for a known one
        check_paths+=("$TOOL_DIR/include/DeckLinkAPI.h")
    elif [ -n "$target_check_filename" ]; then
        # Default to checking lib and lib64 for libraries
        check_paths+=("$target_path_lib" "$target_path_lib64")
    fi
    # If check_paths is empty, build_needed will default to YES below

    local source_path="$SOURCE_DIR/$source_subdir"
    local skip_flag_var="SKIP_$(echo $libname | tr '[:lower:]-' '[:upper:]_')"

    # --- Check if explicitly skipped by user ---
    if [ "$(eval echo \$$skip_flag_var)" = "YES" ]; then
        echoSection "skip $libname (user request)"
        # Create skip file for test script compatibility?
        echo "YES" > "$LOG_DIR/skip-$libname"
        # Ensure FFmpeg flags are NOT added if skipped by user
        # (The logic below handles this)
        return
    fi

    # --- Determine if build is needed ---
    local build_needed="YES" # Default to build unless found
    if [ "$FORCE_REBUILD" = "YES" ]; then
        echo "Force rebuild requested for $libname."
        build_needed="YES"
    elif [ ${#check_paths[@]} -gt 0 ]; then
        # Check the specified paths
        build_needed="YES" # Assume not found initially
        for check_path in "${check_paths[@]}"; do
            echo "DEBUG: Checking for $libname artifact at: $check_path"
            if [ -f "$check_path" ] || [ -L "$check_path" ]; then # Check for file or symlink
                echo "DEBUG: Found artifact: $check_path"
                found_path="$check_path"
                build_needed="NO"
                break # Found it, no need to check further or build
            fi
        done
        if [ "$build_needed" = "YES" ]; then
             echo "Target artifact not found for $libname in expected locations. Building."
        fi
    else
        # No check file specified, assume build is needed
        echo "DEBUG: No target check file specified for $libname. Building."
        build_needed="YES"
    fi

    # --- Perform Build if Needed ---
    if [ "$build_needed" = "YES" ]; then
        # Clean source directory first
        if [ -d "$source_path" ]; then
            echo "Cleaning source directory: $source_path"
            rm -rf "$source_path"
            checkStatus $? "Failed to clean source directory $source_path"
        fi

        START_TIME=$(currentTimeInSeconds)
        echoSection "compile $libname"
        # Run the build script
        "$SCRIPT_DIR/$script_name.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" "${extra_args[@]}" > "$LOG_DIR/${script_name}.log" 2>&1
        BUILD_EXIT_CODE=$?
        if [ $BUILD_EXIT_CODE -ne 0 ]; then
            echo "ERROR: build $libname failed. Check log $LOG_DIR/${script_name}.log"
            exit 1
        fi

        # Verify target file was created after build (if specified)
        local verify_ok="NO"
        if [ ${#check_paths[@]} -eq 0 ]; then
            verify_ok="YES" # No file to check, assume OK if build didn't fail
        else
            for check_path in "${check_paths[@]}"; do
                if [ -f "$check_path" ] || [ -L "$check_path" ]; then
                    verify_ok="YES"
                    found_path="$check_path"
                    echo "DEBUG: Verified artifact exists after build: $found_path"
                    break
                fi
            done
        fi
        if [ "$verify_ok" = "NO" ]; then
             echo "ERROR: build $libname seemed to succeed but target artifact was not found in expected locations!"
             echo "       Checked: ${check_paths[@]}"
             exit 1
        fi
        echoDurationInSections $START_TIME
    else
        echoSection "Skipping $libname (already built - found $found_path)"
    fi # End build_needed check

    # --- Update FFmpeg Flags (only if NOT skipped by user) ---
    if [ -n "$ffmpeg_flag" ]; then
        FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS $ffmpeg_flag"
    fi
    if [ "$is_gpl" = "YES" ]; then
        REQUIRES_GPL="YES"
    fi
    if [ "$is_nonfree" = "YES" ]; then
        REQUIRES_NON_FREE="YES"
    fi
    # Create skip file for test script compatibility?
    echo "NO" > "$LOG_DIR/skip-$libname"

} # End run_build function definition


# --- Build Tools & Foundational Libs ---
# Usage: run_build <libname> <script_name> <target_check_filename> <source_subdir> <ffmpeg_flag> <is_gpl> <is_nonfree> [extra_args...]
run_build "nasm" "build-nasm" "nasm" "nasm" "" "NO" "NO"
# run_build "pkg-config" "build-pkg-config" "pkg-config" "pkg-config" "" "NO" "NO" "$TOOL_DIR"
run_build "zlib" "build-zlib" "libz.a" "zlib" "" "NO" "NO"
run_build "openssl" "build-openssl" "libssl.a" "openssl" "" "NO" "NO" # FFmpeg links ssl & crypto
run_build "cmake" "build-cmake" "cmake" "cmake" "" "NO" "NO"
run_build "ninja" "build-ninja" "ninja" "ninja" "" "NO" "NO"
run_build "libxml2" "build-libxml2" "libxml2.a" "libxml2" "--enable-libxml2" "NO" "NO"

# --- Text / Subtitle Chain ---
run_build "fribidi" "build-fribidi" "libfribidi.a" "fribidi" "" "NO" "NO"
run_build "freetype" "build-freetype" "libfreetype.a" "freetype" "--enable-libfreetype" "NO" "NO"
run_build "fontconfig" "build-fontconfig" "libfontconfig.a" "fontconfig" "--enable-fontconfig" "NO" "NO"
run_build "harfbuzz" "build-harfbuzz" "libharfbuzz.a" "harfbuzz" "--enable-libharfbuzz" "NO" "NO"
run_build "libass" "build-libass" "libass.a" "libass" "--enable-libass" "NO" "NO"

# --- Other Libraries ---
run_build "sdl" "build-sdl" "libSDL2.a" "sdl" "" "NO" "NO" # Needed for ffplay?
run_build "libbluray" "build-libbluray" "libbluray.a" "libbluray" "--enable-libbluray" "NO" "NO"
run_build "snappy" "build-snappy" "libsnappy.a" "snappy" "--enable-libsnappy" "NO" "NO" # <<< Failed previously
run_build "srt" "build-srt" "libsrt.a" "srt" "--enable-libsrt" "NO" "NO" # <<< Failed now
run_build "libvmaf" "build-libvmaf" "libvmaf.a" "libvmaf" "--enable-libvmaf" "NO" "NO"
run_build "libklvanc" "build-libklvanc" "libklvanc.a" "libklvanc" "--enable-libklvanc" "NO" "NO"
run_build "libogg" "build-libogg" "libogg.a" "libogg" "" "NO" "NO" # Dependency for vorbis/theora
run_build "zimg" "build-zimg" "libzimg.a" "zimg" "--enable-libzimg" "NO" "NO"
run_build "zvbi" "build-zvbi" "libzvbi.a" "zvbi" "--enable-libzvbi" "NO" "NO"

# --- Video Codecs ---
run_build "aom" "build-aom" "libaom.a" "aom" "--enable-libaom" "NO" "NO"
run_build "dav1d" "build-dav1d" "libdav1d.a" "dav1d" "--enable-libdav1d" "NO" "NO"
run_build "openh264" "build-openh264" "libopenh264.a" "openh264" "--enable-libopenh264" "NO" "NO"
run_build "openJPEG" "build-openjpeg" "libopenjp2.a" "openjpeg" "--enable-libopenjpeg" "NO" "NO"
run_build "rav1e" "build-rav1e" "librav1e.a" "rav1e" "--enable-librav1e" "NO" "NO"
run_build "svt-av1" "build-svt-av1" "libSvtAv1Enc.a" "svt-av1" "--enable-libsvtav1" "NO" "NO"
run_build "vpx" "build-vpx" "libvpx.a" "vpx" "--enable-libvpx" "NO" "NO"
run_build "libwebp" "build-libwebp" "libwebp.a" "libwebp" "--enable-libwebp" "NO" "NO"
run_build "x264" "build-x264" "libx264.a" "x264" "--enable-libx264" "YES" "NO"
run_build "x265" "build-x265" "libx265.a" "x265" "--enable-libx265" "YES" "NO" "$SKIP_X265_MULTIBIT" # Pass extra arg
run_build "vvenc" "build-vvenc" "libvvenc.a" "vvenc" "--enable-libvvenc" "NO" "NO"
run_build "vvdec" "build-vvdec" "libvvdec.a" "vvdec" "--enable-libvvdec" "NO" "NO"

# --- Audio Codecs ---
run_build "lame" "build-lame" "libmp3lame.a" "lame" "--enable-libmp3lame" "NO" "NO"
run_build "opus" "build-opus" "libopus.a" "opus" "--enable-libopus" "NO" "NO"
run_build "libvorbis" "build-libvorbis" "libvorbis.a" "libvorbis" "--enable-libvorbis" "NO" "NO"
run_build "libtheora" "build-libtheora" "libtheora.a" "libtheora" "--enable-libtheora" "NO" "NO" # Depends on libvorbis

# --- Special: Decklink ---
# Keep Decklink separate as it uses SDK path and checks include dir
if [ "$SKIP_DECKLINK" = "NO" ]; then
    if [ -z "$DECKLINK_SDK" ]; then
        echo "ERROR: Decklink build requested but -DECKLINK_SDK=/path/to/sdk not provided."
        exit 1
    fi
    DECKLINK_HEADER_CHECK="$TOOL_DIR/include/DeckLinkAPI.h"
    build_needed="YES"
    if [ "$FORCE_REBUILD" = "YES" ]; then
        echo "Force rebuild requested for Decklink SDK copy."
        rm -f "$TOOL_DIR/include/DeckLinkAPI*.h" # Clean installed headers
    elif [ -f "$DECKLINK_HEADER_CHECK" ]; then
        build_needed="NO"
        echoSection "Skipping Decklink SDK copy (already present - found $DECKLINK_HEADER_CHECK)"
    fi

    if [ "$build_needed" = "YES" ]; then
        START_TIME=$(currentTimeInSeconds)
        echoSection "prepare decklink SDK"
        "$SCRIPT_DIR/build-decklink.sh" "$SCRIPT_DIR" "$TOOL_DIR" "$DECKLINK_SDK" > "$LOG_DIR/build-decklink.log" 2>&1
         if [ $? -ne 0 ]; then
            echo "ERROR: Decklink SDK preparation failed. Check log $LOG_DIR/build-decklink.log"
            exit 1
        fi
         if [ ! -f "$DECKLINK_HEADER_CHECK" ]; then
             echo "ERROR: Decklink SDK copy seemed to succeed but target header $DECKLINK_HEADER_CHECK was not found!"
             exit 1
        fi
        echoDurationInSections $START_TIME
    fi

    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-decklink"
    REQUIRES_NON_FREE="YES"
    echo "NO" > "$LOG_DIR/skip-decklink"
else
    echoSection "skip decklink SDK"
    echo "YES" > "$LOG_DIR/skip-decklink"
fi


# --- Final FFmpeg Configuration Flags ---
echoSection "check additional build flags"
if [ $REQUIRES_GPL = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-gpl $FFMPEG_LIB_FLAGS"
    echo "requires GPL build flag"
fi
if [ $REQUIRES_NON_FREE = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-nonfree $FFMPEG_LIB_FLAGS"
    echo "requires non-free build flag"
fi
FFMPEG_LIB_FLAGS="--enable-version3 $FFMPEG_LIB_FLAGS"
FFMPEG_LIB_FLAGS="--enable-demuxer=dash $FFMPEG_LIB_FLAGS"


# --- Compile FFmpeg ---
START_TIME=$(currentTimeInSeconds)
echoSection "compile ffmpeg"
FFMPEG_SOURCE_PATH="$SOURCE_DIR/ffmpeg"
if [ "$FORCE_REBUILD" = "YES" ] || [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    if [ -d "$FFMPEG_SOURCE_PATH" ]; then
        echo "Cleaning FFmpeg source directory: $FFMPEG_SOURCE_PATH"
        rm -rf "$FFMPEG_SOURCE_PATH"
        checkStatus $? "Failed to clean FFmpeg source directory"
    fi
fi
"$SCRIPT_DIR/build-ffmpeg.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$OUT_DIR" "$CPUS" "$FFMPEG_SNAPSHOT" "$SKIP_VVDEC" "$FFMPEG_LIB_FLAGS" "$ENABLE_FFMPEG_PGO" > "$LOG_DIR/build-ffmpeg.log" 2>&1
checkStatus $? "build ffmpeg"
echoDurationInSections $START_TIME

echoSection "compilation finished successfully"
echoDurationInSections $COMPILATION_START_TIME


# --- Bundle Result ---
if [ "$SKIP_BUNDLE" = "NO" ]; then
    echoSection "bundle result into tar.gz"
    echo "DEBUG: Checking contents of OUT_DIR ($OUT_DIR) before bundling:"
    ls -lA "$OUT_DIR"
    echo "-------------------------------------------"
    if [ -z "$(ls -A "$OUT_DIR")" ]; then
        echo "ERROR: OUT_DIR ($OUT_DIR) is empty or does not exist. Skipping bundling."
    else
        echo "Archiving non-hidden contents of $OUT_DIR using subshell..."
        (cd "$OUT_DIR" && tar -czf "$WORKING_DIR/ffmpeg-build.tar.gz" *)
        checkStatus $? "bundling failed"
        echo "DEBUG: Listing contents of created tarball:"
        tar -tzf "$WORKING_DIR/ffmpeg-build.tar.gz"
        echo "-------------------------------------------"
    fi
fi


# --- Run Tests ---
if [ $SKIP_TEST = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run tests"
    if [ -f "$TEST_DIR/test.sh" ]; then
        "$TEST_DIR/test.sh" "$SCRIPT_DIR" "$TEST_DIR" "$TEST_OUT_DIR" "$OUT_DIR" "$LOG_DIR" > "$LOG_DIR/test.log" 2>&1
        checkStatus $? "test failed. Check $LOG_DIR/test.log and $TEST_OUT_DIR/*.log"
        echo "tests executed successfully"
    else
         echo "Warning: Test script $TEST_DIR/test.sh not found, skipping tests."
    fi
    echoDurationInSections $START_TIME
fi

echo "Build script finished."