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

# Force GCC compiler
export CC=gcc
export CXX=g++
export AR=ar
export NM=nm
export RANLIB=ranlib
export LD=ld # Use default system linker
echo "Using GCC: CC=$CC, CXX=$CXX, AR=$AR, NM=$NM, RANLIB=$RANLIB, LD=$LD"

# parse arguments
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
DECKLINK_SDK=""
ENABLE_FFMPEG_PGO="YES" # Default to YES, can be overridden
FFMPEG_SNAPSHOT="YES"
CPU_LIMIT=""
# Add flag to force rebuild of all dependencies
FORCE_REBUILD="NO"

for arg in "$@"; do
    KEY=${arg%%=*}
    VALUE=${arg#*\=}
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

# some folder names
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

# load functions
. $SCRIPT_DIR/functions.sh

# prepare workspace
echoSection "prepare workspace"
mkdir -p "$SOURCE_DIR" # Use -p to avoid error if exists
checkStatus $? "unable to create source code directory"
mkdir -p "$LOG_DIR"
checkStatus $? "unable to create logs directory"
mkdir -p "$TOOL_DIR"
checkStatus $? "unable to create tool directory"
mkdir -p "$TOOL_DIR/lib" # Ensure lib dir exists for checks
mkdir -p "$TOOL_DIR/bin" # Ensure bin dir exists
PATH="$TOOL_DIR/bin:$PATH"
mkdir -p "$OUT_DIR"
checkStatus $? "unable to create output directory"
if [ $SKIP_TEST = "NO" ]; then
    mkdir -p "$TEST_OUT_DIR"
    checkStatus $? "unable to create test output directory"
fi

# Set environment variables globally for dependency builds
echo "Exporting paths for build environment (with -fPIC):"
echo "  Include Path: ${TOOL_DIR}/include"
echo "  Library Path: ${TOOL_DIR}/lib"
echo "  PkgConfig Path: ${TOOL_DIR}/lib/pkgconfig"

# Set flags directly, assuming no critical external flags need preserving for this build
export CFLAGS="-I${TOOL_DIR}/include -fPIC"
export CPPFLAGS="-I${TOOL_DIR}/include -fPIC" # Often same as CFLAGS for includes
export CXXFLAGS="-I${TOOL_DIR}/include -fPIC"
export LDFLAGS="-L${TOOL_DIR}/lib"
export PKG_CONFIG_PATH="${TOOL_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}" # Appending PKG_CONFIG_PATH is usually safe/intended

# detect CPU threads (nproc for linux, sysctl for osx)
CPUS=1
if [ "$CPU_LIMIT" != "" ]; then
    CPUS=$CPU_LIMIT
else
    CPUS_NPROC="$(nproc 2> /dev/null)"
    if [ $? -eq 0 ]; then
        CPUS=$CPUS_NPROC
    else
        CPUS_SYSCTL="$(sysctl -n hw.ncpu 2> /dev/null)"
        if [ $? -eq 0 ]; then
            CPUS=$CPUS_SYSCTL
        fi
    fi
fi

echo "use ${CPUS} cpu threads"
echo "system info: $(uname -a)"
COMPILATION_START_TIME=$(currentTimeInSeconds)

# prepare build
FFMPEG_LIB_FLAGS=""
REQUIRES_GPL="NO"
REQUIRES_NON_FREE="NO"

# --- Build Dependencies ---

# Function to wrap build calls with skip logic and source cleaning
# Usage: run_build <libname> <script_name> <target_lib_filename> <source_subdir> <ffmpeg_flag> <is_gpl> <is_nonfree> [extra_args...]
# Example: run_build "zlib" "build-zlib" "libz.a" "zlib" "" "NO" "NO"
run_build() {
    local libname=$1
    local script_name=$2
    local target_lib_filename=$3 # e.g., libz.a or libx264.a
    local source_subdir=$4      # e.g., zlib or x264
    local ffmpeg_flag=$5
    local is_gpl=$6
    local is_nonfree=$7
    shift 7 # Remove first 7 args, rest are extra_args for build script
    local extra_args=("$@")

    local target_lib_path="$TOOL_DIR/lib/$target_lib_filename"
    local source_path="$SOURCE_DIR/$source_subdir"
    local skip_flag_var="SKIP_$(echo $libname | tr '[:lower:]-' '[:upper:]_')" # e.g., SKIP_ZLIB

    # Check if user explicitly skipped this lib
    if [ "$(eval echo \$$skip_flag_var)" = "YES" ]; then
        echoSection "skip $libname (user request)"
        echo "YES" > "$LOG_DIR/skip-$libname" # Keep this for compatibility with test script if needed
        return
    fi

    # Determine if build is needed
    local build_needed="NO"
    if [ "$FORCE_REBUILD" = "YES" ]; then
        build_needed="YES"
        echo "Force rebuild requested for $libname."
    elif [ ! -f "$target_lib_path" ]; then
        build_needed="YES"
        echo "Target library $target_lib_path not found for $libname. Building."
    else
        echoSection "Skipping $libname (already built - found $target_lib_path)"
    fi

    # Perform build if needed
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
        if [ $? -ne 0 ]; then
            echo "ERROR: build $libname failed. Check log $LOG_DIR/${script_name}.log"
            exit 1
        fi
        # Verify target lib was created after build
        if [ -n "$target_lib_filename" ] && [ ! -f "$target_lib_path" ]; then
             echo "ERROR: build $libname seemed to succeed but target library $target_lib_path was not found!"
             exit 1
        fi
        echoDurationInSections $START_TIME
    fi

    # Always add FFmpeg flags if the library wasn't explicitly skipped by the user
    if [ -n "$ffmpeg_flag" ]; then
        FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS $ffmpeg_flag"
    fi
    if [ "$is_gpl" = "YES" ]; then
        REQUIRES_GPL="YES"
    fi
    if [ "$is_nonfree" = "YES" ]; then
        REQUIRES_NON_FREE="YES"
    fi
    echo "NO" > "$LOG_DIR/skip-$libname" # Keep this for compatibility with test script if needed
}

# Build Tools & Foundational Libs (Adapt args for run_build)
# For tools like nasm, cmake, ninja, pkg-config, we check for binary existence instead of library
run_build "nasm" "build-nasm" "../bin/nasm" "nasm" "" "NO" "NO"
run_build "pkg-config" "build-pkg-config" "../bin/pkg-config" "pkg-config" "" "NO" "NO" "$TOOL_DIR" # Extra arg
run_build "zlib" "build-zlib" "libz.a" "zlib" "" "NO" "NO"
run_build "openssl" "build-openssl" "libssl.a" "openssl" "" "NO" "NO"
run_build "cmake" "build-cmake" "../bin/cmake" "cmake" "" "NO" "NO"
run_build "ninja" "build-ninja" "../bin/ninja" "ninja" "" "NO" "NO"
run_build "libxml2" "build-libxml2" "libxml2.a" "libxml2" "--enable-libxml2" "NO" "NO"

# Text / Subtitle Rendering Chain
run_build "fribidi" "build-fribidi" "libfribidi.a" "fribidi" "" "NO" "NO"
run_build "freetype" "build-freetype" "libfreetype.a" "freetype" "--enable-libfreetype" "NO" "NO"
run_build "fontconfig" "build-fontconfig" "libfontconfig.a" "fontconfig" "--enable-fontconfig" "NO" "NO"
run_build "harfbuzz" "build-harfbuzz" "libharfbuzz.a" "harfbuzz" "--enable-libharfbuzz" "NO" "NO"
run_build "libass" "build-libass" "libass.a" "libass" "--enable-libass" "NO" "NO"

# Other Libraries
run_build "sdl" "build-sdl" "libSDL2.a" "sdl" "" "NO" "NO" # Needed for ffplay
run_build "libbluray" "build-libbluray" "libbluray.a" "libbluray" "--enable-libbluray" "NO" "NO"
run_build "snappy" "build-snappy" "libsnappy.a" "snappy" "--enable-libsnappy" "NO" "NO"
run_build "srt" "build-srt" "libsrt.a" "srt" "--enable-libsrt" "NO" "NO"
run_build "libvmaf" "build-libvmaf" "libvmaf.a" "libvmaf" "--enable-libvmaf" "NO" "NO"
run_build "libklvanc" "build-libklvanc" "libklvanc.a" "libklvanc" "--enable-libklvanc" "NO" "NO"
run_build "libogg" "build-libogg" "libogg.a" "libogg" "" "NO" "NO" # Dependency for vorbis/theora
run_build "zimg" "build-zimg" "libzimg.a" "zimg" "--enable-libzimg" "NO" "NO"
run_build "zvbi" "build-zvbi" "libzvbi.a" "zvbi" "--enable-libzvbi" "NO" "NO"

# Video Codecs
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

# Audio Codecs
run_build "lame" "build-lame" "libmp3lame.a" "lame" "--enable-libmp3lame" "NO" "NO"
run_build "opus" "build-opus" "libopus.a" "opus" "--enable-libopus" "NO" "NO"
run_build "libvorbis" "build-libvorbis" "libvorbis.a" "libvorbis" "--enable-libvorbis" "NO" "NO"
run_build "libtheora" "build-libtheora" "libtheora.a" "libtheora" "--enable-libtheora" "NO" "NO" # Depends on libvorbis

# Special: Decklink (Requires manual SDK path)
if [ "$SKIP_DECKLINK" = "NO" ]; then
    if [ -z "$DECKLINK_SDK" ]; then
        echo "ERROR: Decklink build requested but -DECKLINK_SDK=/path/to/sdk not provided."
        exit 1
    fi
    # Decklink doesn't produce a library in TOOL_DIR/lib, it copies headers.
    # Check for header existence as a proxy for "success".
    # We assume the source subdir doesn't need cleaning as it's user-provided.
    # The build script just copies headers.
    DECKLINK_HEADER="$TOOL_DIR/include/DeckLinkAPI.h"
    DECKLINK_SOURCE_SUBDIR="" # No source subdir to clean for this one.

    build_needed="NO"
    if [ "$FORCE_REBUILD" = "YES" ]; then
        build_needed="YES"
        echo "Force rebuild requested for Decklink SDK copy."
        # Clean the installed headers if forcing rebuild
         if [ -f "$DECKLINK_HEADER" ]; then rm -f "$TOOL_DIR/include/DeckLinkAPI*.h"; fi
    elif [ ! -f "$DECKLINK_HEADER" ]; then
        build_needed="YES"
        echo "Decklink header $DECKLINK_HEADER not found. Copying SDK."
    else
        echoSection "Skipping Decklink SDK copy (already present - found $DECKLINK_HEADER)"
    fi

    if [ "$build_needed" = "YES" ]; then
        START_TIME=$(currentTimeInSeconds)
        echoSection "prepare decklink SDK"
        "$SCRIPT_DIR/build-decklink.sh" "$SCRIPT_DIR" "$TOOL_DIR" "$DECKLINK_SDK" > "$LOG_DIR/build-decklink.log" 2>&1
         if [ $? -ne 0 ]; then
            echo "ERROR: Decklink SDK preparation failed. Check log $LOG_DIR/build-decklink.log"
            exit 1
        fi
         # Verify target header was created after build
        if [ ! -f "$DECKLINK_HEADER" ]; then
             echo "ERROR: Decklink SDK copy seemed to succeed but target header $DECKLINK_HEADER was not found!"
             exit 1
        fi
        echoDurationInSections $START_TIME
    fi

    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-decklink"
    REQUIRES_NON_FREE="YES"
    echo "NO" > "$LOG_DIR/skip-decklink"
fi


# check other ffmpeg flags
echoSection "check additional build flags"
if [ $REQUIRES_GPL = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-gpl $FFMPEG_LIB_FLAGS"
    echo "requires GPL build flag"
fi
if [ $REQUIRES_NON_FREE = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-nonfree $FFMPEG_LIB_FLAGS"
    echo "requires non-free build flag"
fi
# Enable GPL/LGPL v3
FFMPEG_LIB_FLAGS="--enable-version3 $FFMPEG_LIB_FLAGS"
# Enable dash demuxer
FFMPEG_LIB_FLAGS="--enable-demuxer=dash $FFMPEG_LIB_FLAGS"

START_TIME=$(currentTimeInSeconds)
echoSection "compile ffmpeg"
# Clean FFmpeg source before building? Usually configure handles this, but PGO might benefit.
# Let's add cleaning for FFmpeg source as well if PGO is enabled or forced rebuild
FFMPEG_SOURCE_PATH="$SOURCE_DIR/ffmpeg"
if [ "$FORCE_REBUILD" = "YES" ] || [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    if [ -d "$FFMPEG_SOURCE_PATH" ]; then
        echo "Cleaning FFmpeg source directory: $FFMPEG_SOURCE_PATH"
        rm -rf "$FFMPEG_SOURCE_PATH"
        checkStatus $? "Failed to clean FFmpeg source directory"
    fi
fi

# vvdec needs to patch ffmpeg. Pass SKIP_VVDEC status to ffmpeg build script.
# FFmpeg build itself is not skipped by this mechanism
"$SCRIPT_DIR/build-ffmpeg.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$OUT_DIR" "$CPUS" "$FFMPEG_SNAPSHOT" "$SKIP_VVDEC" "$FFMPEG_LIB_FLAGS" "$ENABLE_FFMPEG_PGO" > "$LOG_DIR/build-ffmpeg.log" 2>&1
checkStatus $? "build ffmpeg"
echoDurationInSections $START_TIME

echoSection "compilation finished successfully"
echoDurationInSections $COMPILATION_START_TIME

# relocateDylib (If needed for shared builds on macOS - likely not needed for Linux shared build)

if [ "$SKIP_BUNDLE" = "NO" ]; then
    echoSection "bundle result into tar.gz"
    # Exclude hidden files/directories
    tar --exclude='.*' -czf "$WORKING_DIR/ffmpeg-build.tar.gz" -C "$OUT_DIR" .
    checkStatus $? "bundling failed"
fi

if [ $SKIP_TEST = "NO" ]; then
    # Before running tests, ensure the skip-<libname> files reflect the actual build status
    # The run_build function already creates these files based on whether the lib was skipped or built
    START_TIME=$(currentTimeInSeconds)
    echoSection "run tests"
    "$TEST_DIR/test.sh" "$SCRIPT_DIR" "$TEST_DIR" "$TEST_OUT_DIR" "$OUT_DIR" "$LOG_DIR" > "$LOG_DIR/test.log" 2>&1
    checkStatus $? "test failed. Check $LOG_DIR/test.log and $TEST_OUT_DIR/*.log"
    echo "tests executed successfully"
    echoDurationInSections $START_TIME
fi