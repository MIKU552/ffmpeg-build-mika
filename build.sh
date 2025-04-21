#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
# --- Added Modifications for Skip/Clean Logic ---

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
SKIP_VVENC="NO"
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
# SKIP_VVENC="NO" # Already defined above
DECKLINK_SDK=""
FFMPEG_SNAPSHOT="YES"
CPU_LIMIT=""
for arg in "$@"; do
    KEY=${arg%%=*}
    VALUE=${arg#*\=}
    if [ $KEY = "-SKIP_BUNDLE" ]; then
        SKIP_BUNDLE=$VALUE
        echo "skip bundle $VALUE"
    fi
    if [ $KEY = "-SKIP_TEST" ]; then
        SKIP_TEST=$VALUE
        echo "skip test $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBBLURAY" ]; then
        SKIP_LIBBLURAY=$VALUE
        echo "skip libbluray $VALUE"
    fi
    if [ $KEY = "-SKIP_SNAPPY" ]; then
        SKIP_SNAPPY=$VALUE
        echo "skip snappy $VALUE"
    fi
    if [ $KEY = "-SKIP_SRT" ]; then
        SKIP_SRT=$VALUE
        echo "skip srt $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBVMAF" ]; then
        SKIP_LIBVMAF=$VALUE
        echo "skip libvmaf $VALUE"
    fi
    if [ $KEY = "-SKIP_ZIMG" ]; then
        SKIP_ZIMG=$VALUE
        echo "skip zimg $VALUE"
    fi
    if [ $KEY = "-SKIP_ZVBI" ]; then
        SKIP_ZVBI=$VALUE
        echo "skip zvbi $VALUE"
    fi
    if [ $KEY = "-SKIP_AOM" ]; then
        SKIP_AOM=$VALUE
        echo "skip aom $VALUE"
    fi
    if [ $KEY = "-SKIP_DAV1D" ]; then
        SKIP_DAV1D=$VALUE
        echo "skip dav1d $VALUE"
    fi
    if [ $KEY = "-SKIP_OPEN_H264" ]; then
        SKIP_OPEN_H264=$VALUE
        echo "skip openh264 $VALUE"
    fi
    if [ $KEY = "-SKIP_OPEN_JPEG" ]; then
        SKIP_OPEN_JPEG=$VALUE
        echo "skip openJPEG $VALUE"
    fi
    if [ $KEY = "-SKIP_RAV1E" ]; then
        SKIP_RAV1E=$VALUE
        echo "skip rav1e $VALUE"
    fi
    if [ $KEY = "-SKIP_SVT_AV1" ]; then
        SKIP_SVT_AV1=$VALUE
        echo "skip svt-av1 $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBTHEORA" ]; then
        SKIP_LIBTHEORA=$VALUE
        echo "skip libtheora $VALUE"
    fi
    if [ $KEY = "-SKIP_VPX" ]; then
        SKIP_VPX=$VALUE
        echo "skip vpx $VALUE"
    fi
    if [ $KEY = "-SKIP_VVENC" ]; then
        SKIP_VVENC=$VALUE
        echo "skip vvenc $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBWEBP" ]; then
        SKIP_LIBWEBP=$VALUE
        echo "skip libwebp $VALUE"
    fi
    if [ $KEY = "-SKIP_X264" ]; then
        SKIP_X264=$VALUE
        echo "skip x264 $VALUE"
    fi
    if [ $KEY = "-SKIP_X265" ]; then
        SKIP_X265=$VALUE
        echo "skip x265 $VALUE"
    fi
    if [ $KEY = "-SKIP_X265_MULTIBIT" ]; then
        SKIP_X265_MULTIBIT=$VALUE
        echo "skip x265 multibit $VALUE"
    fi
    if [ $KEY = "-SKIP_LAME" ]; then
        SKIP_LAME=$VALUE
        echo "skip lame (mp3) $VALUE"
    fi
    if [ $KEY = "-SKIP_OPUS" ]; then
        SKIP_OPUS=$VALUE
        echo "skip opus $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBVORBIS" ]; then
        SKIP_LIBVORBIS=$VALUE
        echo "skip libvorbis $VALUE"
    fi
    if [ $KEY = "-SKIP_LIBKLVANC" ]; then
        SKIP_LIBKLVANC=$VALUE
        echo "skip libklvanc $VALUE"
    fi
    if [ $KEY = "-SKIP_DECKLINK" ]; then
        SKIP_DECKLINK=$VALUE
        echo "skip decklink $VALUE"
    fi
    if [ $KEY = "-SKIP_VVDEC" ]; then
        SKIP_VVDEC=$VALUE
        echo "skip vvdec $VALUE"
    fi
    # if [ $KEY = "-SKIP_VVENC" ]; then # Already defined above
    #     SKIP_VVENC=$VALUE
    #     echo "skip vvenc $VALUE"
    # fi
    if [ $KEY = "-DECKLINK_SDK" ]; then
        DECKLINK_SDK=$VALUE
        echo "use decklink SDK folder $VALUE"
    fi
    if [ $KEY = "-FFMPEG_SNAPSHOT" ]; then
        FFMPEG_SNAPSHOT=$VALUE
        echo "use ffmpeg snapshot $VALUE"
    fi
    if [ $KEY = "-CPU_LIMIT" ]; then
        CPU_LIMIT=$VALUE
        echo "use cpu limit $VALUE"
    fi
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
mkdir -p "$LOG_DIR" # Use -p
checkStatus $? "unable to create logs directory"
mkdir -p "$TOOL_DIR" # Use -p
checkStatus $? "unable to create tool directory"
PATH="$TOOL_DIR/bin:$PATH"
mkdir -p "$OUT_DIR" # Use -p
checkStatus $? "unable to create output directory"
if [ $SKIP_TEST = "NO" ]; then
    mkdir -p "$TEST_OUT_DIR" # Use -p
    checkStatus $? "unable to create test output directory"
fi

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

# --- Start Build Process with Skip/Clean Logic ---

# nasm
MARKER_NASM="$LOG_DIR/build-nasm.success"
SOURCE_NASM="$SOURCE_DIR/nasm"
if [ -f "$MARKER_NASM" ]; then
    echoSection "skip nasm (already completed)"
else
    echoSection "compile nasm"
    echo "Cleaning source directory $SOURCE_NASM..."
    rm -rf "$SOURCE_NASM"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-nasm.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-nasm.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build nasm"
    echo "Marking nasm as successfully built."
    touch "$MARKER_NASM"
    checkStatus $? "create success marker for nasm failed"
    echoDurationInSections $START_TIME
fi

# libiconv (Original script skips this, maintaining that behavior)
echoSection "skip libiconv (not built by this script)"
echo "YES" > "$LOG_DIR/skip-libiconv" # Keep this log for compatibility if tests use it

# pkg-config
MARKER_PKGCONFIG="$LOG_DIR/build-pkg-config.success"
SOURCE_PKGCONFIG="$SOURCE_DIR/pkg-config"
if [ -f "$MARKER_PKGCONFIG" ]; then
    echoSection "skip pkg-config (already completed)"
else
    echoSection "compile pkg-config"
    echo "Cleaning source directory $SOURCE_PKGCONFIG..."
    rm -rf "$SOURCE_PKGCONFIG"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-pkg-config.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" > "$LOG_DIR/build-pkg-config.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build pkg-config"
    echo "Marking pkg-config as successfully built."
    touch "$MARKER_PKGCONFIG"
    checkStatus $? "create success marker for pkg-config failed"
    echoDurationInSections $START_TIME
fi

# zlib
MARKER_ZLIB="$LOG_DIR/build-zlib.success"
SOURCE_ZLIB="$SOURCE_DIR/zlib"
if [ -f "$MARKER_ZLIB" ]; then
    echoSection "skip zlib (already completed)"
else
    echoSection "compile zlib"
    echo "Cleaning source directory $SOURCE_ZLIB..."
    rm -rf "$SOURCE_ZLIB"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-zlib.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-zlib.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build zlib"
    echo "Marking zlib as successfully built."
    touch "$MARKER_ZLIB"
    checkStatus $? "create success marker for zlib failed"
    echoDurationInSections $START_TIME
fi

# openssl
MARKER_OPENSSL="$LOG_DIR/build-openssl.success"
SOURCE_OPENSSL="$SOURCE_DIR/openssl"
if [ -f "$MARKER_OPENSSL" ]; then
    echoSection "skip openssl (already completed)"
else
    echoSection "compile openssl"
    echo "Cleaning source directory $SOURCE_OPENSSL..."
    rm -rf "$SOURCE_OPENSSL"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-openssl.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-openssl.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build openssl"
    echo "Marking openssl as successfully built."
    touch "$MARKER_OPENSSL"
    checkStatus $? "create success marker for openssl failed"
    echoDurationInSections $START_TIME
fi

# cmake
MARKER_CMAKE="$LOG_DIR/build-cmake.success"
SOURCE_CMAKE="$SOURCE_DIR/cmake"
if [ -f "$MARKER_CMAKE" ]; then
    echoSection "skip cmake (already completed)"
else
    echoSection "compile cmake"
    echo "Cleaning source directory $SOURCE_CMAKE..."
    rm -rf "$SOURCE_CMAKE"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-cmake.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-cmake.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build cmake"
    echo "Marking cmake as successfully built."
    touch "$MARKER_CMAKE"
    checkStatus $? "create success marker for cmake failed"
    echoDurationInSections $START_TIME
fi

# ninja
MARKER_NINJA="$LOG_DIR/build-ninja.success"
SOURCE_NINJA="$SOURCE_DIR/ninja"
if [ -f "$MARKER_NINJA" ]; then
    echoSection "skip ninja (already completed)"
else
    echoSection "compile ninja"
    echo "Cleaning source directory $SOURCE_NINJA..."
    rm -rf "$SOURCE_NINJA"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-ninja.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-ninja.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build ninja"
    echo "Marking ninja as successfully built."
    touch "$MARKER_NINJA"
    checkStatus $? "create success marker for ninja failed"
    echoDurationInSections $START_TIME
fi

# libxml2
MARKER_LIBXML2="$LOG_DIR/build-libxml2.success"
SOURCE_LIBXML2="$SOURCE_DIR/libxml2"
if [ -f "$MARKER_LIBXML2" ]; then
    echoSection "skip libxml2 (already completed)"
else
    echoSection "compile libxml2"
    echo "Cleaning source directory $SOURCE_LIBXML2..."
    rm -rf "$SOURCE_LIBXML2"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-libxml2.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libxml2.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build libxml2"
    echo "Marking libxml2 as successfully built."
    touch "$MARKER_LIBXML2"
    checkStatus $? "create success marker for libxml2 failed"
    echoDurationInSections $START_TIME
fi
# FFMPEG flag depends on libxml2 being available (always enabled in this script's default)
FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libxml2"

# fribidi
MARKER_FRIBIDI="$LOG_DIR/build-fribidi.success"
SOURCE_FRIBIDI="$SOURCE_DIR/fribidi"
if [ -f "$MARKER_FRIBIDI" ]; then
    echoSection "skip fribidi (already completed)"
else
    echoSection "compile fribidi"
    echo "Cleaning source directory $SOURCE_FRIBIDI..."
    rm -rf "$SOURCE_FRIBIDI"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-fribidi.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-fribidi.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build fribidi"
    echo "Marking fribidi as successfully built."
    touch "$MARKER_FRIBIDI"
    checkStatus $? "create success marker for fribidi failed"
    echoDurationInSections $START_TIME
fi

# freetype
MARKER_FREETYPE="$LOG_DIR/build-freetype.success"
SOURCE_FREETYPE="$SOURCE_DIR/freetype"
if [ -f "$MARKER_FREETYPE" ]; then
    echoSection "skip freetype (already completed)"
else
    echoSection "compile freetype"
    echo "Cleaning source directory $SOURCE_FREETYPE..."
    rm -rf "$SOURCE_FREETYPE"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-freetype.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-freetype.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build freetype"
    echo "Marking freetype as successfully built."
    touch "$MARKER_FREETYPE"
    checkStatus $? "create success marker for freetype failed"
    echoDurationInSections $START_TIME
fi
# FFMPEG flag depends on freetype being available (always enabled)
FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libfreetype"

# fontconfig
MARKER_FONTCONFIG="$LOG_DIR/build-fontconfig.success"
SOURCE_FONTCONFIG="$SOURCE_DIR/fontconfig"
if [ -f "$MARKER_FONTCONFIG" ]; then
    echoSection "skip fontconfig (already completed)"
else
    echoSection "compile fontconfig"
    echo "Cleaning source directory $SOURCE_FONTCONFIG..."
    rm -rf "$SOURCE_FONTCONFIG"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-fontconfig.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-fontconfig.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build fontconfig"
    echo "Marking fontconfig as successfully built."
    touch "$MARKER_FONTCONFIG"
    checkStatus $? "create success marker for fontconfig failed"
    echoDurationInSections $START_TIME
fi
# FFMPEG flag depends on fontconfig being available (always enabled)
FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-fontconfig"

# harfbuzz
MARKER_HARFBUZZ="$LOG_DIR/build-harfbuzz.success"
SOURCE_HARFBUZZ="$SOURCE_DIR/harfbuzz"
if [ -f "$MARKER_HARFBUZZ" ]; then
    echoSection "skip harfbuzz (already completed)"
else
    echoSection "compile harfbuzz"
    echo "Cleaning source directory $SOURCE_HARFBUZZ..."
    rm -rf "$SOURCE_HARFBUZZ"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-harfbuzz.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-harfbuzz.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build harfbuzz"
    echo "Marking harfbuzz as successfully built."
    touch "$MARKER_HARFBUZZ"
    checkStatus $? "create success marker for harfbuzz failed"
    echoDurationInSections $START_TIME
fi
# FFMPEG flag depends on harfbuzz being available (always enabled)
FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libharfbuzz"
echo "NO" > "$LOG_DIR/skip-libharfbuzz" # Keep for test script compatibility?

# SDL
MARKER_SDL="$LOG_DIR/build-sdl.success"
SOURCE_SDL="$SOURCE_DIR/sdl"
if [ -f "$MARKER_SDL" ]; then
    echoSection "skip SDL (already completed)"
else
    echoSection "compile SDL"
    echo "Cleaning source directory $SOURCE_SDL..."
    rm -rf "$SOURCE_SDL"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-sdl.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-sdl.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build SDL"
    echo "Marking SDL as successfully built."
    touch "$MARKER_SDL"
    checkStatus $? "create success marker for SDL failed"
    echoDurationInSections $START_TIME
fi

# Conditional builds start here
if [ $SKIP_LIBBLURAY = "NO" ]; then
    MARKER_LIBBLURAY="$LOG_DIR/build-libbluray.success"
    SOURCE_LIBBLURAY="$SOURCE_DIR/libbluray"
    if [ -f "$MARKER_LIBBLURAY" ]; then
        echoSection "skip libbluray (already completed)"
    else
        echoSection "compile libbluray"
        echo "Cleaning source directory $SOURCE_LIBBLURAY..."
        rm -rf "$SOURCE_LIBBLURAY"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libbluray.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libbluray.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libbluray"
        echo "Marking libbluray as successfully built."
        touch "$MARKER_LIBBLURAY"
        checkStatus $? "create success marker for libbluray failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libbluray"
    echo "NO" > "$LOG_DIR/skip-libbluray"
else
    echoSection "skip libbluray"
    echo "YES" > "$LOG_DIR/skip-libbluray"
fi

if [ $SKIP_SNAPPY = "NO" ]; then
    MARKER_SNAPPY="$LOG_DIR/build-snappy.success"
    SOURCE_SNAPPY="$SOURCE_DIR/snappy"
    if [ -f "$MARKER_SNAPPY" ]; then
        echoSection "skip snappy (already completed)"
    else
        echoSection "compile snappy"
        echo "Cleaning source directory $SOURCE_SNAPPY..."
        rm -rf "$SOURCE_SNAPPY"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-snappy.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-snappy.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build snappy"
        echo "Marking snappy as successfully built."
        touch "$MARKER_SNAPPY"
        checkStatus $? "create success marker for snappy failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libsnappy"
    echo "NO" > "$LOG_DIR/skip-snappy"
else
    echoSection "skip snappy"
    echo "YES" > "$LOG_DIR/skip-snappy"
fi

if [ $SKIP_SRT = "NO" ]; then
    MARKER_SRT="$LOG_DIR/build-srt.success"
    SOURCE_SRT="$SOURCE_DIR/srt"
    if [ -f "$MARKER_SRT" ]; then
        echoSection "skip srt (already completed)"
    else
        echoSection "compile srt"
        echo "Cleaning source directory $SOURCE_SRT..."
        rm -rf "$SOURCE_SRT"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-srt.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-srt.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build srt"
        echo "Marking srt as successfully built."
        touch "$MARKER_SRT"
        checkStatus $? "create success marker for srt failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libsrt"
    echo "NO" > "$LOG_DIR/skip-srt"
else
    echoSection "skip srt"
    echo "YES" > "$LOG_DIR/skip-srt"
fi

if [ $SKIP_LIBVMAF = "NO" ]; then
    MARKER_LIBVMAF="$LOG_DIR/build-libvmaf.success"
    SOURCE_LIBVMAF="$SOURCE_DIR/libvmaf"
    if [ -f "$MARKER_LIBVMAF" ]; then
        echoSection "skip libvmaf (already completed)"
    else
        echoSection "compile libvmaf"
        echo "Cleaning source directory $SOURCE_LIBVMAF..."
        rm -rf "$SOURCE_LIBVMAF"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libvmaf.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libvmaf.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libvmaf"
        echo "Marking libvmaf as successfully built."
        touch "$MARKER_LIBVMAF"
        checkStatus $? "create success marker for libvmaf failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libvmaf"
    echo "NO" > "$LOG_DIR/skip-libvmaf"
else
    echoSection "skip libvmaf"
    echo "YES" > "$LOG_DIR/skip-libvmaf"
fi

# libass (Always built if not skipped at top level - checking SKIP_ variable is redundant here but kept for pattern consistency)
# Note: Assuming libass is *not* skippable via a command-line arg in the original script logic being preserved.
MARKER_LIBASS="$LOG_DIR/build-libass.success"
SOURCE_LIBASS="$SOURCE_DIR/libass"
if [ -f "$MARKER_LIBASS" ]; then
    echoSection "skip libass (already completed)"
else
    echoSection "compile libass"
    echo "Cleaning source directory $SOURCE_LIBASS..."
    rm -rf "$SOURCE_LIBASS"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-libass.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libass.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build libass"
    echo "Marking libass as successfully built."
    touch "$MARKER_LIBASS"
    checkStatus $? "create success marker for libass failed"
    echoDurationInSections $START_TIME
fi
# FFMPEG flag depends on libass being available (always enabled)
FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libass"

if [ $SKIP_LIBKLVANC = "NO" ]; then
    MARKER_LIBKLVANC="$LOG_DIR/build-libklvanc.success"
    SOURCE_LIBKLVANC="$SOURCE_DIR/libklvanc"
    if [ -f "$MARKER_LIBKLVANC" ]; then
        echoSection "skip libklvanc (already completed)"
    else
        echoSection "compile libklvanc"
        echo "Cleaning source directory $SOURCE_LIBKLVANC..."
        rm -rf "$SOURCE_LIBKLVANC"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libklvanc.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libklvanc.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libklvanc"
        echo "Marking libklvanc as successfully built."
        touch "$MARKER_LIBKLVANC"
        checkStatus $? "create success marker for libklvanc failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libklvanc"
    echo "NO" > "$LOG_DIR/skip-libklvanc"
else
    echoSection "skip libklvanc"
    echo "YES" > "$LOG_DIR/skip-libklvanc"
fi

# libogg (Always built)
MARKER_LIBOGG="$LOG_DIR/build-libogg.success"
SOURCE_LIBOGG="$SOURCE_DIR/libogg"
if [ -f "$MARKER_LIBOGG" ]; then
    echoSection "skip libogg (already completed)"
else
    echoSection "compile libogg"
    echo "Cleaning source directory $SOURCE_LIBOGG..."
    rm -rf "$SOURCE_LIBOGG"
    START_TIME=$(currentTimeInSeconds)
    $SCRIPT_DIR/build-libogg.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libogg.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build libogg"
    echo "Marking libogg as successfully built."
    touch "$MARKER_LIBOGG"
    checkStatus $? "create success marker for libogg failed"
    echoDurationInSections $START_TIME
fi

if [ $SKIP_ZIMG = "NO" ]; then
    MARKER_ZIMG="$LOG_DIR/build-zimg.success"
    SOURCE_ZIMG="$SOURCE_DIR/zimg"
    if [ -f "$MARKER_ZIMG" ]; then
        echoSection "skip zimg (already completed)"
    else
        echoSection "compile zimg"
        echo "Cleaning source directory $SOURCE_ZIMG..."
        rm -rf "$SOURCE_ZIMG"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-zimg.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-zimg.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build zimg"
        echo "Marking zimg as successfully built."
        touch "$MARKER_ZIMG"
        checkStatus $? "create success marker for zimg failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libzimg"
    echo "NO" > "$LOG_DIR/skip-zimg"
else
    echoSection "skip zimg"
    echo "YES" > "$LOG_DIR/skip-zimg"
fi

if [ $SKIP_ZVBI = "NO" ]; then
    MARKER_ZVBI="$LOG_DIR/build-zvbi.success"
    SOURCE_ZVBI="$SOURCE_DIR/zvbi"
    if [ -f "$MARKER_ZVBI" ]; then
        echoSection "skip zvbi (already completed)"
    else
        echoSection "compile zvbi"
        echo "Cleaning source directory $SOURCE_ZVBI..."
        rm -rf "$SOURCE_ZVBI"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-zvbi.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-zvbi.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build zvbi"
        echo "Marking zvbi as successfully built."
        touch "$MARKER_ZVBI"
        checkStatus $? "create success marker for zvbi failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libzvbi"
    echo "NO" > "$LOG_DIR/skip-zvbi"
else
    echoSection "skip zvbi"
    echo "YES" > "$LOG_DIR/skip-zvbi"
fi

if [ $SKIP_AOM = "NO" ]; then
    MARKER_AOM="$LOG_DIR/build-aom.success"
    SOURCE_AOM="$SOURCE_DIR/aom"
    if [ -f "$MARKER_AOM" ]; then
        echoSection "skip aom (already completed)"
    else
        echoSection "compile aom"
        echo "Cleaning source directory $SOURCE_AOM..."
        rm -rf "$SOURCE_AOM"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-aom.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-aom.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build aom"
        echo "Marking aom as successfully built."
        touch "$MARKER_AOM"
        checkStatus $? "create success marker for aom failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libaom"
    echo "NO" > "$LOG_DIR/skip-aom"
else
    echoSection "skip aom"
    echo "YES" > "$LOG_DIR/skip-aom"
fi

if [ $SKIP_DAV1D = "NO" ]; then
    MARKER_DAV1D="$LOG_DIR/build-dav1d.success"
    SOURCE_DAV1D="$SOURCE_DIR/dav1d"
    if [ -f "$MARKER_DAV1D" ]; then
        echoSection "skip dav1d (already completed)"
    else
        echoSection "compile dav1d"
        echo "Cleaning source directory $SOURCE_DAV1D..."
        rm -rf "$SOURCE_DAV1D"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-dav1d.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-dav1d.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build dav1d"
        echo "Marking dav1d as successfully built."
        touch "$MARKER_DAV1D"
        checkStatus $? "create success marker for dav1d failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libdav1d"
    echo "NO" > "$LOG_DIR/skip-dav1d"
else
    echoSection "skip dav1d"
    echo "YES" > "$LOG_DIR/skip-dav1d"
fi

if [ $SKIP_OPEN_H264 = "NO" ]; then
    MARKER_OPENH264="$LOG_DIR/build-openh264.success"
    SOURCE_OPENH264="$SOURCE_DIR/openh264"
    if [ -f "$MARKER_OPENH264" ]; then
        echoSection "skip openh264 (already completed)"
    else
        echoSection "compile openh264"
        echo "Cleaning source directory $SOURCE_OPENH264..."
        rm -rf "$SOURCE_OPENH264"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-openh264.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-openh264.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build openh264"
        echo "Marking openh264 as successfully built."
        touch "$MARKER_OPENH264"
        checkStatus $? "create success marker for openh264 failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libopenh264"
    echo "NO" > "$LOG_DIR/skip-openh264"
else
    echoSection "skip openh264"
    echo "YES" > "$LOG_DIR/skip-openh264"
fi

if [ $SKIP_OPEN_JPEG = "NO" ]; then
    MARKER_OPENJPEG="$LOG_DIR/build-openjpeg.success"
    SOURCE_OPENJPEG="$SOURCE_DIR/openjpeg"
    if [ -f "$MARKER_OPENJPEG" ]; then
        echoSection "skip openJPEG (already completed)"
    else
        echoSection "compile openJPEG"
        echo "Cleaning source directory $SOURCE_OPENJPEG..."
        rm -rf "$SOURCE_OPENJPEG"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-openjpeg.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-openJPEG.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build openJPEG"
        echo "Marking openJPEG as successfully built."
        touch "$MARKER_OPENJPEG"
        checkStatus $? "create success marker for openJPEG failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libopenjpeg"
    echo "NO" > "$LOG_DIR/skip-openJPEG"
else
    echoSection "skip openJPEG"
    echo "YES" > "$LOG_DIR/skip-openJPEG"
fi

if [ $SKIP_RAV1E = "NO" ]; then
    MARKER_RAV1E="$LOG_DIR/build-rav1e.success"
    SOURCE_RAV1E="$SOURCE_DIR/rav1e"
    if [ -f "$MARKER_RAV1E" ]; then
        echoSection "skip rav1e (already completed)"
    else
        echoSection "compile rav1e"
        echo "Cleaning source directory $SOURCE_RAV1E..."
        rm -rf "$SOURCE_RAV1E"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-rav1e.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-rav1e.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build rav1e"
        echo "Marking rav1e as successfully built."
        touch "$MARKER_RAV1E"
        checkStatus $? "create success marker for rav1e failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-librav1e"
    echo "NO" > "$LOG_DIR/skip-rav1e"
else
    echoSection "skip rav1e"
    echo "YES" > "$LOG_DIR/skip-rav1e"
fi

if [ $SKIP_SVT_AV1 = "NO" ]; then
    MARKER_SVTAV1="$LOG_DIR/build-svt-av1.success"
    SOURCE_SVTAV1="$SOURCE_DIR/svt-av1"
    if [ -f "$MARKER_SVTAV1" ]; then
        echoSection "skip svt-av1 (already completed)"
    else
        echoSection "compile svt-av1"
        echo "Cleaning source directory $SOURCE_SVTAV1..."
        rm -rf "$SOURCE_SVTAV1"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-svt-av1.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-svt-av1.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build svt-av1"
        echo "Marking svt-av1 as successfully built."
        touch "$MARKER_SVTAV1"
        checkStatus $? "create success marker for svt-av1 failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libsvtav1"
    echo "NO" > "$LOG_DIR/skip-svt-av1"
else
    echoSection "skip svt-av1"
    echo "YES" > "$LOG_DIR/skip-svt-av1"
fi

if [ $SKIP_VPX = "NO" ]; then
    MARKER_VPX="$LOG_DIR/build-vpx.success"
    SOURCE_VPX="$SOURCE_DIR/vpx"
    if [ -f "$MARKER_VPX" ]; then
        echoSection "skip vpx (already completed)"
    else
        echoSection "compile vpx"
        echo "Cleaning source directory $SOURCE_VPX..."
        rm -rf "$SOURCE_VPX"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-vpx.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-vpx.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build vpx"
        echo "Marking vpx as successfully built."
        touch "$MARKER_VPX"
        checkStatus $? "create success marker for vpx failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libvpx"
    echo "NO" > "$LOG_DIR/skip-vpx"
else
    echoSection "skip vpx"
    echo "YES" > "$LOG_DIR/skip-vpx"
fi

if [ $SKIP_VVENC = "NO" ]; then
    MARKER_VVENC="$LOG_DIR/build-vvenc.success"
    SOURCE_VVENC="$SOURCE_DIR/vvenc"
    if [ -f "$MARKER_VVENC" ]; then
        echoSection "skip vvenc (already completed)"
    else
        echoSection "compile vvenc"
        echo "Cleaning source directory $SOURCE_VVENC..."
        rm -rf "$SOURCE_VVENC"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-vvenc.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-vvenc.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build vvenc"
        echo "Marking vvenc as successfully built."
        touch "$MARKER_VVENC"
        checkStatus $? "create success marker for vvenc failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libvvenc"
    echo "NO" > "$LOG_DIR/skip-vvenc"
else
    echoSection "skip vvenc"
    echo "YES" > "$LOG_DIR/skip-vvenc"
fi

if [ $SKIP_LIBWEBP = "NO" ]; then
    MARKER_LIBWEBP="$LOG_DIR/build-libwebp.success"
    SOURCE_LIBWEBP="$SOURCE_DIR/libwebp"
    if [ -f "$MARKER_LIBWEBP" ]; then
        echoSection "skip libwebp (already completed)"
    else
        echoSection "compile libwebp"
        echo "Cleaning source directory $SOURCE_LIBWEBP..."
        rm -rf "$SOURCE_LIBWEBP"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libwebp.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libwebp.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libwebp"
        echo "Marking libwebp as successfully built."
        touch "$MARKER_LIBWEBP"
        checkStatus $? "create success marker for libwebp failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libwebp"
    echo "NO" > "$LOG_DIR/skip-libwebp"
else
    echoSection "skip libwebp"
    echo "YES" > "$LOG_DIR/skip-libwebp"
fi

if [ $SKIP_X264 = "NO" ]; then
    MARKER_X264="$LOG_DIR/build-x264.success"
    SOURCE_X264="$SOURCE_DIR/x264"
    if [ -f "$MARKER_X264" ]; then
        echoSection "skip x264 (already completed)"
    else
        echoSection "compile x264"
        echo "Cleaning source directory $SOURCE_X264..."
        rm -rf "$SOURCE_X264"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-x264.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-x264.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build x264"
        echo "Marking x264 as successfully built."
        touch "$MARKER_X264"
        checkStatus $? "create success marker for x264 failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libx264"
    REQUIRES_GPL="YES"
    echo "NO" > "$LOG_DIR/skip-x264"
else
    echoSection "skip x264"
    echo "YES" > "$LOG_DIR/skip-x264"
fi

if [ $SKIP_X265 = "NO" ]; then
    MARKER_X265="$LOG_DIR/build-x265.success"
    SOURCE_X265="$SOURCE_DIR/x265"
    if [ -f "$MARKER_X265" ]; then
        echoSection "skip x265 (already completed)"
    else
        echoSection "compile x265"
        echo "Cleaning source directory $SOURCE_X265..."
        rm -rf "$SOURCE_X265"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-x265.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" "$SKIP_X265_MULTIBIT" > "$LOG_DIR/build-x265.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build x265"
        echo "Marking x265 as successfully built."
        touch "$MARKER_X265"
        checkStatus $? "create success marker for x265 failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libx265"
    REQUIRES_GPL="YES"
    echo "NO" > "$LOG_DIR/skip-x265"
else
    echoSection "skip x265"
    echo "YES" > "$LOG_DIR/skip-x265"
fi

if [ $SKIP_VVDEC = "NO" ]; then
    MARKER_VVDEC="$LOG_DIR/build-vvdec.success"
    SOURCE_VVDEC="$SOURCE_DIR/vvdec"
    if [ -f "$MARKER_VVDEC" ]; then
        echoSection "skip vvdec (already completed)"
    else
        echoSection "compile vvdec"
        echo "Cleaning source directory $SOURCE_VVDEC..."
        rm -rf "$SOURCE_VVDEC"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-vvdec.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-vvdec.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build vvdec"
        echo "Marking vvdec as successfully built."
        touch "$MARKER_VVDEC"
        checkStatus $? "create success marker for vvdec failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libvvdec"
    echo "NO" > "$LOG_DIR/skip-vvdec"
else
    echoSection "skip vvdec"
    echo "YES" > "$LOG_DIR/skip-vvdec"
fi

if [ $SKIP_LAME = "NO" ]; then
    MARKER_LAME="$LOG_DIR/build-lame.success"
    SOURCE_LAME="$SOURCE_DIR/lame"
    if [ -f "$MARKER_LAME" ]; then
        echoSection "skip lame (mp3) (already completed)"
    else
        echoSection "compile lame (mp3)"
        echo "Cleaning source directory $SOURCE_LAME..."
        rm -rf "$SOURCE_LAME"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-lame.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-lame.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build lame"
        echo "Marking lame as successfully built."
        touch "$MARKER_LAME"
        checkStatus $? "create success marker for lame failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libmp3lame"
    echo "NO" > "$LOG_DIR/skip-lame"
else
    echoSection "skip lame (mp3)"
    echo "YES" > "$LOG_DIR/skip-lame"
fi

if [ $SKIP_OPUS = "NO" ]; then
    MARKER_OPUS="$LOG_DIR/build-opus.success"
    SOURCE_OPUS="$SOURCE_DIR/opus"
    if [ -f "$MARKER_OPUS" ]; then
        echoSection "skip opus (already completed)"
    else
        echoSection "compile opus"
        echo "Cleaning source directory $SOURCE_OPUS..."
        rm -rf "$SOURCE_OPUS"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-opus.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-opus.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build opus"
        echo "Marking opus as successfully built."
        touch "$MARKER_OPUS"
        checkStatus $? "create success marker for opus failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libopus"
    echo "NO" > "$LOG_DIR/skip-opus"
else
    echoSection "skip opus"
    echo "YES" > "$LOG_DIR/skip-opus"
fi

if [ $SKIP_LIBVORBIS = "NO" ]; then
    MARKER_LIBVORBIS="$LOG_DIR/build-libvorbis.success"
    SOURCE_LIBVORBIS="$SOURCE_DIR/libvorbis"
    if [ -f "$MARKER_LIBVORBIS" ]; then
        echoSection "skip libvorbis (already completed)"
    else
        echoSection "compile libvorbis"
        echo "Cleaning source directory $SOURCE_LIBVORBIS..."
        rm -rf "$SOURCE_LIBVORBIS"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libvorbis.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libvorbis.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libvorbis"
        echo "Marking libvorbis as successfully built."
        touch "$MARKER_LIBVORBIS"
        checkStatus $? "create success marker for libvorbis failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libvorbis"
    echo "NO" > "$LOG_DIR/skip-libvorbis"
else
    echoSection "skip libvorbis"
    echo "YES" > "$LOG_DIR/skip-libvorbis"
fi

if [ $SKIP_LIBTHEORA = "NO" ]; then
    MARKER_LIBTHEORA="$LOG_DIR/build-libtheora.success"
    SOURCE_LIBTHEORA="$SOURCE_DIR/libtheora"
    if [ -f "$MARKER_LIBTHEORA" ]; then
        echoSection "skip libtheora (already completed)"
    else
        echoSection "compile libtheora"
        echo "Cleaning source directory $SOURCE_LIBTHEORA..."
        rm -rf "$SOURCE_LIBTHEORA"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-libtheora.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" > "$LOG_DIR/build-libtheora.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "build libtheora"
        echo "Marking libtheora as successfully built."
        touch "$MARKER_LIBTHEORA"
        checkStatus $? "create success marker for libtheora failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-libtheora"
    echo "NO" > "$LOG_DIR/skip-libtheora"
else
    echoSection "skip libtheora"
    echo "YES" > "$LOG_DIR/skip-libtheora"
fi

if [ $SKIP_DECKLINK = "NO" ]; then
    MARKER_DECKLINK="$LOG_DIR/build-decklink.success"
    # Decklink doesn't build from source, so no SOURCE_DECKLINK or cleaning needed
    if [ -f "$MARKER_DECKLINK" ]; then
        echoSection "skip decklink SDK setup (already completed)"
    else
        echoSection "prepare decklink SDK"
        START_TIME=$(currentTimeInSeconds)
        $SCRIPT_DIR/build-decklink.sh "$SCRIPT_DIR" "$TOOL_DIR" "$DECKLINK_SDK" > "$LOG_DIR/build-decklink.log" 2>&1
        BUILD_STATUS=$?
        checkStatus $BUILD_STATUS "decklink SDK setup"
        echo "Marking decklink SDK as successfully prepared."
        touch "$MARKER_DECKLINK"
        checkStatus $? "create success marker for decklink failed"
        echoDurationInSections $START_TIME
    fi
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-decklink"
    REQUIRES_NON_FREE="YES"
    echo "NO" > "$LOG_DIR/skip-decklink"
else
    echoSection "skip decklink SDK"
    echo "YES" > "$LOG_DIR/skip-decklink"
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

# --- Compile FFmpeg ---
# This step runs after dependencies are handled. No marker logic needed here,
# but we clean its source dir if re-running the whole script might be desired.
MARKER_FFMPEG="$LOG_DIR/build-ffmpeg.success"
SOURCE_FFMPEG="$SOURCE_DIR/ffmpeg"
if [ -f "$MARKER_FFMPEG" ]; then
    echoSection "skip ffmpeg compilation (already completed)"
else
    echoSection "compile ffmpeg"
    echo "Cleaning source directory $SOURCE_FFMPEG..."
    rm -rf "$SOURCE_FFMPEG"

    START_TIME=$(currentTimeInSeconds)
    # vvdec needs to patch ffmpeg
    $SCRIPT_DIR/build-ffmpeg.sh "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$OUT_DIR" "$CPUS" "$FFMPEG_SNAPSHOT" "$SKIP_VVDEC" "$FFMPEG_LIB_FLAGS" > "$LOG_DIR/build-ffmpeg.log" 2>&1
    BUILD_STATUS=$?
    checkStatus $BUILD_STATUS "build ffmpeg"

    echo "Marking ffmpeg as successfully built."
    touch "$MARKER_FFMPEG"
    checkStatus $? "create success marker for ffmpeg failed"

    echoDurationInSections $START_TIME
fi

echoSection "compilation finished successfully"
echoDurationInSections $COMPILATION_START_TIME

# --- Post Build Steps ---

# Check if FFmpeg actually built before relocating
if [ -f "$MARKER_FFMPEG" ]; then
    echoSection "relocate dylibs"
    START_TIME=$(currentTimeInSeconds)
    relocateDylib
    checkStatus $? "relocating dylibs failed"
    echoDurationInSections $START_TIME
else
    echoSection "skip relocate dylibs (FFmpeg not built in this run)"
fi


if [ $SKIP_BUNDLE = "NO" ]; then
    # Only bundle if FFmpeg build was successful in this run or previously
    if [ -f "$MARKER_FFMPEG" ] || [ -x "$OUT_DIR/bin/ffmpeg" ]; then # Check marker or actual executable
        echoSection "bundle result"
        cd "$OUT_DIR/"
        checkStatus $? "change directory to $OUT_DIR failed"
        zip -9 -r "$WORKING_DIR/ffmpeg-success.zip" *
        checkStatus $? "zipping output failed"
        cd "$WORKING_DIR" # Go back to working directory
        checkStatus $? "change directory back to $WORKING_DIR failed"
    else
        echoSection "skip bundle result (FFmpeg not successfully built)"
    fi
fi

if [ $SKIP_TEST = "NO" ]; then
    # Only test if FFmpeg build was successful
    if [ -f "$MARKER_FFMPEG" ] || [ -x "$OUT_DIR/bin/ffmpeg" ]; then # Check marker or actual executable
        START_TIME=$(currentTimeInSeconds)
        echoSection "run tests"
        $TEST_DIR/test.sh "$SCRIPT_DIR" "$TEST_DIR" "$TEST_OUT_DIR" "$OUT_DIR" "$LOG_DIR" > "$LOG_DIR/test.log" 2>&1
        # Don't exit script if tests fail, just report
        TEST_STATUS=$?
        if [ $TEST_STATUS -ne 0 ]; then
            echo "WARNING: Tests failed! Check $LOG_DIR/test.log and $TEST_OUT_DIR for details."
        else
            echo "tests executed successfully"
        fi
        echoDurationInSections $START_TIME
    else
         echoSection "skip tests (FFmpeg not successfully built)"
    fi
fi

echo "Build script finished."