#!/bin/bash

# Merged FFmpeg Build Script (Linux & macOS)
# Based on scripts by Martin Riedl & Hayden Zheng
# Combined and adapted for cross-platform compatibility

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

# --- Detect OS ---
OS_NAME="$(uname)"
echo "Detected OS: ${OS_NAME}"

# --- Argument Parsing (Defaults) ---
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
# Tool skips
SKIP_NASM="NO"
SKIP_PKG_CONFIG="YES"
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
# Build options
DECKLINK_SDK=""
ENABLE_FFMPEG_PGO="NO" # Enable PGO by default (adjust as needed)
FFMPEG_SNAPSHOT="YES"
CPU_LIMIT=""
FORCE_REBUILD="NO"

# --- Parse Command Line Arguments ---
for arg in "$@"; do
    KEY=${arg%%=*}
    VALUE=${arg#*\=}
    case $KEY in
        -SKIP_BUNDLE) SKIP_BUNDLE=$VALUE; echo "skip bundle $VALUE";;
        -SKIP_TEST) SKIP_TEST=$VALUE; echo "skip test $VALUE";;
        -SKIP_LIBBLURAY) SKIP_LIBBLURAY=$VALUE; echo "skip libbluray $VALUE";;
        -SKIP_SNAPPY) SKIP_SNAPPY=$VALUE; echo "skip snappy $VALUE";;
        -SKIP_SRT) SKIP_SRT=$VALUE; echo "skip srt $VALUE";;
        -SKIP_LIBVMAF) SKIP_LIBVMAF=$VALUE; echo "skip libvmaf $VALUE";;
        -SKIP_ZIMG) SKIP_ZIMG=$VALUE; echo "skip zimg $VALUE";;
        -SKIP_ZVBI) SKIP_ZVBI=$VALUE; echo "skip zvbi $VALUE";;
        -SKIP_AOM) SKIP_AOM=$VALUE; echo "skip aom $VALUE";;
        -SKIP_DAV1D) SKIP_DAV1D=$VALUE; echo "skip dav1d $VALUE";;
        -SKIP_OPEN_H264) SKIP_OPEN_H264=$VALUE; echo "skip openh264 $VALUE";;
        -SKIP_OPEN_JPEG) SKIP_OPEN_JPEG=$VALUE; echo "skip openJPEG $VALUE";;
        -SKIP_RAV1E) SKIP_RAV1E=$VALUE; echo "skip rav1e $VALUE";;
        -SKIP_SVT_AV1) SKIP_SVT_AV1=$VALUE; echo "skip svt-av1 $VALUE";;
        -SKIP_LIBTHEORA) SKIP_LIBTHEORA=$VALUE; echo "skip libtheora $VALUE";;
        -SKIP_VPX) SKIP_VPX=$VALUE; echo "skip vpx $VALUE";;
        -SKIP_LIBWEBP) SKIP_LIBWEBP=$VALUE; echo "skip libwebp $VALUE";;
        -SKIP_X264) SKIP_X264=$VALUE; echo "skip x264 $VALUE";;
        -SKIP_X265) SKIP_X265=$VALUE; echo "skip x265 $VALUE";;
        -SKIP_X265_MULTIBIT) SKIP_X265_MULTIBIT=$VALUE; echo "skip x265 multibit $VALUE";;
        -SKIP_LAME) SKIP_LAME=$VALUE; echo "skip lame (mp3) $VALUE";;
        -SKIP_OPUS) SKIP_OPUS=$VALUE; echo "skip opus $VALUE";;
        -SKIP_LIBVORBIS) SKIP_LIBVORBIS=$VALUE; echo "skip libvorbis $VALUE";;
        -SKIP_LIBKLVANC) SKIP_LIBKLVANC=$VALUE; echo "skip libklvanc $VALUE";;
        -SKIP_DECKLINK) SKIP_DECKLINK=$VALUE; echo "skip decklink $VALUE";;
        -SKIP_VVDEC) SKIP_VVDEC=$VALUE; echo "skip vvdec $VALUE";;
        -SKIP_VVENC) SKIP_VVENC=$VALUE; echo "skip vvenc $VALUE";;
        -SKIP_NASM) SKIP_NASM=$VALUE; echo "skip nasm $VALUE";;
        -SKIP_PKG_CONFIG) SKIP_PKG_CONFIG=$VALUE; echo "skip pkg-config $VALUE";;
        -SKIP_ZLIB) SKIP_ZLIB=$VALUE; echo "skip zlib $VALUE";;
        -SKIP_OPENSSL) SKIP_OPENSSL=$VALUE; echo "skip openssl $VALUE";;
        -SKIP_CMAKE) SKIP_CMAKE=$VALUE; echo "skip cmake $VALUE";;
        -SKIP_NINJA) SKIP_NINJA=$VALUE; echo "skip ninja $VALUE";;
        -SKIP_LIBXML2) SKIP_LIBXML2=$VALUE; echo "skip libxml2 $VALUE";;
        -SKIP_FRIBIDI) SKIP_FRIBIDI=$VALUE; echo "skip fribidi $VALUE";;
        -SKIP_FREETYPE) SKIP_FREETYPE=$VALUE; echo "skip freetype $VALUE";;
        -SKIP_FONTCONFIG) SKIP_FONTCONFIG=$VALUE; echo "skip fontconfig $VALUE";;
        -SKIP_HARFBUZZ) SKIP_HARFBUZZ=$VALUE; echo "skip harfbuzz $VALUE";;
        -SKIP_SDL) SKIP_SDL=$VALUE; echo "skip SDL $VALUE";;
        -SKIP_LIBASS) SKIP_LIBASS=$VALUE; echo "skip libass $VALUE";;
        -SKIP_LIBOGG) SKIP_LIBOGG=$VALUE; echo "skip libogg $VALUE";;
        -ENABLE_FFMPEG_PGO) ENABLE_FFMPEG_PGO=$VALUE; echo "enable ffmpeg pgo $VALUE";;
        -DECKLINK_SDK) DECKLINK_SDK=$VALUE; echo "use decklink SDK folder $VALUE";;
        -FFMPEG_SNAPSHOT) FFMPEG_SNAPSHOT=$VALUE; echo "use ffmpeg snapshot $VALUE";;
        -CPU_LIMIT) CPU_LIMIT=$VALUE; echo "use cpu limit $VALUE";;
        -FORCE_REBUILD) FORCE_REBUILD=$VALUE; echo "force rebuild $VALUE";;
        *) echo "Unknown argument: $arg";;
    esac
done

# --- Directory Definitions ---
BASE_DIR="$( cd "$( dirname "$0" )" > /dev/null 2>&1 && pwd )"
echo "base directory is ${BASE_DIR}"
# Assume script and test dirs are relative to BASE_DIR
SCRIPT_DIR="${BASE_DIR}/script"
echo "script directory is ${SCRIPT_DIR}"
WORKING_DIR="$( pwd )"
echo "working directory is ${WORKING_DIR}"
SOURCE_DIR="$WORKING_DIR/source"
echo "source code directory is ${SOURCE_DIR}"
LOG_DIR="$WORKING_DIR/log"
echo "logs directory is ${LOG_DIR}"
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
    # shellcheck source=./script/functions.sh
    . "$SCRIPT_DIR/functions.sh"
else
    echo "ERROR: functions.sh not found in $SCRIPT_DIR"
    exit 1
fi


# --- Prepare Workspace ---
echoSection "Prepare Workspace"
mkdir -p "$SOURCE_DIR"
checkStatus $? "unable to create source code directory"
mkdir -p "$LOG_DIR"
checkStatus $? "unable to create logs directory"
mkdir -p "$TOOL_DIR"
checkStatus $? "unable to create tool directory"
mkdir -p "$TOOL_DIR/bin"
mkdir -p "$TOOL_DIR/lib"
# Create lib64 on Linux just in case, macOS doesn't typically use it
if [ "$OS_NAME" = "Linux" ]; then
    mkdir -p "$TOOL_DIR/lib64"
fi
mkdir -p "$TOOL_DIR/include"
mkdir -p "$TOOL_DIR/lib/pkgconfig"
if [ "$OS_NAME" = "Linux" ]; then
    mkdir -p "$TOOL_DIR/lib64/pkgconfig"
fi
# Prepend TOOL_DIR/bin to PATH *after* potentially setting compiler paths
# PATH="$TOOL_DIR/bin:$PATH" # Moved lower

mkdir -p "$OUT_DIR"
checkStatus $? "unable to create output directory"
if [ $SKIP_TEST = "NO" ]; then
    mkdir -p "$TEST_OUT_DIR"
    checkStatus $? "unable to create test output directory"
fi

# --- Setup Global Build Environment ---
echoSection "Setup Global Build Environment for OS: ${OS_NAME}"

# --- Compiler Selection ---
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Using Clang (Xcode default)"
    # CC, CXX etc. are usually set correctly by Xcode's environment
    # Ensure command line tools are installed: xcode-select --install
    # Explicitly setting might override Xcode defaults, use with caution if needed
    # export CC=clang
    # export CXX=clang++
    # export AR=ar
    # export NM=nm
    # export RANLIB=ranlib
    # export LD=ld
else # Assuming Linux
    echo "Using GCC"
    export CC=gcc
    export CXX=g++
    export AR=ar
    export NM=nm
    export RANLIB=ranlib
    export LD=ld
    echo "Set: CC=$CC, CXX=$CXX, AR=$AR, NM=$NM, RANLIB=$RANLIB, LD=$LD"
fi

# --- Environment Variables ---
# Use -fPIC for shared object compatibility, especially on Linux
# macOS often handles this differently (default behavior might be position-independent)
PIC_FLAG=""
if [ "$OS_NAME" = "Linux" ]; then
    PIC_FLAG="-fPIC"
fi

# Set environment variables globally for dependency builds
echo "Exporting paths for build environment (${PIC_FLAG}):"
echo "  Include Path: ${TOOL_DIR}/include"
echo "  Library Path(s): ${TOOL_DIR}/lib" $([ "$OS_NAME" = "Linux" ] && echo "and ${TOOL_DIR}/lib64")
echo "  PkgConfig Path(s): ${TOOL_DIR}/lib/pkgconfig" $([ "$OS_NAME" = "Linux" ] && echo "and ${TOOL_DIR}/lib64/pkgconfig")

export CFLAGS="-I${TOOL_DIR}/include ${PIC_FLAG}"
export CPPFLAGS="-I${TOOL_DIR}/include ${PIC_FLAG}"
export CXXFLAGS="-I${TOOL_DIR}/include ${PIC_FLAG}"

LDFLAGS_PATHS="-L${TOOL_DIR}/lib"
PKG_CONFIG_PATHS="${TOOL_DIR}/lib/pkgconfig"
if [ "$OS_NAME" = "Linux" ]; then
    LDFLAGS_PATHS="$LDFLAGS_PATHS -L${TOOL_DIR}/lib64"
    PKG_CONFIG_PATHS="$PKG_CONFIG_PATHS:${TOOL_DIR}/lib64/pkgconfig"
fi
export LDFLAGS="$LDFLAGS_PATHS"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATHS}:${PKG_CONFIG_PATH}" # Prepend custom paths

# Prepend TOOL_DIR/bin to PATH now
export PATH="$TOOL_DIR/bin:$PATH"

echo "CFLAGS=${CFLAGS}"
echo "CPPFLAGS=${CPPFLAGS}"
echo "CXXFLAGS=${CXXFLAGS}"
echo "LDFLAGS=${LDFLAGS}"
echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
echo "PATH=${PATH}"


# --- Force Rebuild Logic ---
if [ "$FORCE_REBUILD" = "YES" ]; then
    echoSection "Forcing rebuild, relevant target files will be ignored/overwritten"
    # Cleaning source dirs handled by run_build function
fi


# --- Detect CPU Threads ---
CPUS=1
if [ "$CPU_LIMIT" != "" ]; then
    CPUS=$CPU_LIMIT
else
    CPUS_NPROC="$(nproc 2> /dev/null)"
    if [ $? -eq 0 ] && [ "$CPUS_NPROC" -gt 0 ]; then
        CPUS=$CPUS_NPROC
    elif [ "$OS_NAME" = "Darwin" ]; then
        CPUS_SYSCTL="$(sysctl -n hw.ncpu 2> /dev/null)"
        if [ $? -eq 0 ] && [ "$CPUS_SYSCTL" -gt 0 ]; then
            CPUS=$CPUS_SYSCTL
        fi
    fi
    # Fallback if still not found
    if [ "$CPUS" -le 0 ]; then CPUS=1; fi
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
# target_check_filename: Can be libfoo.a, libfoo.so, bin/foo, or just foo if installed to bin
run_build() {
    local libname=$1
    local script_name=$2
    local target_check_filename=$3 # e.g., libz.a or nasm or pkg-config or libSDL2.dylib
    local source_subdir=$4         # e.g., zlib or nasm
    local ffmpeg_flag=$5
    local is_gpl=$6
    local is_nonfree=$7
    shift 7 # Remove first 7 args, rest are extra_args for build script
    local extra_args=("$@")

    # Determine potential paths based on target filename convention
    local target_path_lib="$TOOL_DIR/lib/$target_check_filename"
    local target_path_lib64=""
    if [ "$OS_NAME" = "Linux" ]; then
        target_path_lib64="$TOOL_DIR/lib64/$target_check_filename"
    fi
    local target_path_bin="$TOOL_DIR/bin/$target_check_filename"
    local target_path_include="$TOOL_DIR/include/$target_check_filename" # For headers like decklink

    # Determine which path(s) to check primarily
    local check_paths=()
    local found_path=""
    # Check bin first for tools
    if [[ "$libname" == "nasm" || "$libname" == "cmake" || "$libname" == "ninja" || "$libname" == "pkg-config" ]]; then
        check_paths+=("$target_path_bin")
    fi
    # Check include for Decklink header
    if [[ "$libname" == "decklink" ]]; then
        check_paths+=("$TOOL_DIR/include/DeckLinkAPI.h")
    fi
     # Check lib and potentially lib64 for libraries (.a, .so, .dylib)
    if [[ "$target_check_filename" == *.a || "$target_check_filename" == *.so || "$target_check_filename" == *.dylib ]]; then
         check_paths+=("$target_path_lib")
         if [ -n "$target_path_lib64" ]; then
             check_paths+=("$target_path_lib64")
         fi
    fi

    # If no paths determined yet, assume it's a library and check lib/lib64
    if [ ${#check_paths[@]} -eq 0 ] && [ -n "$target_check_filename" ]; then
         check_paths+=("$target_path_lib")
         if [ -n "$target_path_lib64" ]; then
             check_paths+=("$target_path_lib64")
         fi
    fi

    local source_path="$SOURCE_DIR/$source_subdir"
    local skip_flag_var="SKIP_$(echo "$libname" | tr '[:lower:]-' '[:upper:]_')"

    # --- Check if explicitly skipped by user ---
    if [ "$(eval echo "\$$skip_flag_var")" = "YES" ]; then
        echoSection "Skip $libname (user request)"
        # Create skip file for test script compatibility
        echo "YES" > "$LOG_DIR/skip-$libname"
        return
    fi

    # --- Determine if build is needed ---
    local build_needed="YES" # Default to build unless found
    if [ "$FORCE_REBUILD" = "YES" ]; then
        echo "Force rebuild requested for $libname."
        build_needed="YES"
    elif [ ${#check_paths[@]} -gt 0 ]; then
        build_needed="YES" # Assume not found initially
        for check_path in "${check_paths[@]}"; do
            echo "DEBUG: Checking for $libname artifact at: $check_path"
            if [ -e "$check_path" ]; then # Check for file/dir/symlink existence
                echo "DEBUG: Found artifact: $check_path"
                found_path="$check_path"
                build_needed="NO"
                break # Found it
            fi
        done
        if [ "$build_needed" = "YES" ]; then
             echo "Target artifact not found for $libname in expected locations: ${check_paths[*]}. Building."
        fi
    else
        echo "DEBUG: No target check file specified for $libname, or couldn't determine check paths. Building."
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
        echoSection "Compile $libname"
        # Run the build script, passing OS_NAME might be useful for some scripts
        # "$SCRIPT_DIR/$script_name.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" "$OS_NAME" "${extra_args[@]}" > "$LOG_DIR/${script_name}.log" 2>&1
        # Simpler approach: Let scripts detect OS via uname
        "$SCRIPT_DIR/$script_name.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" "${extra_args[@]}" > "$LOG_DIR/${script_name}.log" 2>&1
        BUILD_EXIT_CODE=$?
        if [ $BUILD_EXIT_CODE -ne 0 ]; then
            echo "ERROR: Build $libname failed. Check log $LOG_DIR/${script_name}.log"
            cat "$LOG_DIR/${script_name}.log" # Print log on failure
            exit 1
        fi

        # Verify target file was created after build (if specified)
        local verify_ok="NO"
        if [ ${#check_paths[@]} -eq 0 ]; then
            verify_ok="YES" # No file to check, assume OK if build didn't fail
        else
            for check_path in "${check_paths[@]}"; do
                if [ -e "$check_path" ]; then
                    verify_ok="YES"
                    found_path="$check_path"
                    echo "DEBUG: Verified artifact exists after build: $found_path"
                    break
                fi
            done
        fi
        if [ "$verify_ok" = "NO" ]; then
             echo "ERROR: Build $libname seemed to succeed but target artifact was not found in expected locations!"
             echo "       Checked: ${check_paths[*]}"
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
    # Create skip file for test script compatibility
    echo "NO" > "$LOG_DIR/skip-$libname"

} # End run_build function definition


# --- Build Tools & Foundational Libs ---
# Target filename conventions:
# - Tools: Executable name (e.g., "nasm") -> check bin/
# - Libraries: Static (.a) or Shared (.so/.dylib) -> check lib/ and maybe lib64/
# Note: FFmpeg prefers static libs, but the script builds shared FFmpeg.
# The build scripts for dependencies *should* build static libs (.a) for linking into FFmpeg's shared libs.
# macOS uses .dylib for shared, Linux uses .so. We primarily check for .a as that's what FFmpeg links against.

# Usage: run_build <libname> <script_name> <target_check_filename> <source_subdir> <ffmpeg_flag> <is_gpl> <is_nonfree> [extra_args...]
run_build "nasm" "build-nasm" "nasm" "nasm" "" "NO" "NO"
run_build "pkg-config" "build-pkg-config" "pkg-config" "pkg-config" "" "NO" "NO" "$TOOL_DIR"
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
SDL_TARGET="libSDL2.a" # Check for static lib
# SDL might install shared lib too, but FFmpeg needs static link for this build type
# if [ "$OS_NAME" = "Darwin" ]; then SDL_TARGET="libSDL2.dylib"; else SDL_TARGET="libSDL2.so"; fi
run_build "sdl" "build-sdl" "$SDL_TARGET" "sdl" "" "NO" "NO" # Needed for ffplay
run_build "libbluray" "build-libbluray" "libbluray.a" "libbluray" "--enable-libbluray" "NO" "NO"
run_build "snappy" "build-snappy" "libsnappy.a" "snappy" "--enable-libsnappy" "NO" "NO"
run_build "srt" "build-srt" "libsrt.a" "srt" "--enable-libsrt" "NO" "NO"
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
        echo "ERROR: Decklink build requested but -DECKLINK_SDK=/path/to/sdk/include not provided."
        exit 1
    fi
    run_build "decklink" "build-decklink" "DeckLinkAPI.h" "" "--enable-decklink" "NO" "YES" "$DECKLINK_SDK"
    # Note: The run_build call above handles the check/build/flag logic
    # We removed the redundant checks/logic from the original Linux script here.
else
    echoSection "Skip Decklink SDK (user request)"
    echo "YES" > "$LOG_DIR/skip-decklink"
fi


# --- Final FFmpeg Configuration Flags ---
echoSection "Check additional build flags"
if [ "$REQUIRES_GPL" = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-gpl $FFMPEG_LIB_FLAGS"
    echo "Requires GPL build flag"
fi
if [ "$REQUIRES_NON_FREE" = "YES" ]; then
    FFMPEG_LIB_FLAGS="--enable-nonfree $FFMPEG_LIB_FLAGS"
    echo "Requires non-free build flag"
fi
FFMPEG_LIB_FLAGS="--enable-version3 $FFMPEG_LIB_FLAGS" # Enable GPL/LGPL v3 features
FFMPEG_LIB_FLAGS="--enable-demuxer=dash $FFMPEG_LIB_FLAGS" # Explicitly enable dash

# Add macOS specific flags
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Adding macOS specific flags: --enable-videotoolbox --enable-audiotoolbox"
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-videotoolbox --enable-audiotoolbox"
fi


# --- Compile FFmpeg ---
START_TIME=$(currentTimeInSeconds)
echoSection "Compile FFmpeg"
FFMPEG_SOURCE_PATH="$SOURCE_DIR/ffmpeg"
# Clean FFmpeg source if forcing rebuild OR if PGO is enabled (as PGO involves multiple configure/make steps)
if [ "$FORCE_REBUILD" = "YES" ] || [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    if [ -d "$FFMPEG_SOURCE_PATH" ]; then
        echo "Cleaning FFmpeg source directory: $FFMPEG_SOURCE_PATH"
        rm -rf "$FFMPEG_SOURCE_PATH"
        checkStatus $? "Failed to clean FFmpeg source directory"
    fi
fi
# Pass OS_NAME to ffmpeg build script if it needs internal logic, otherwise it can use uname
# Passing ENABLE_FFMPEG_PGO to control PGO steps inside build-ffmpeg.sh
"$SCRIPT_DIR/build-ffmpeg.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$OUT_DIR" "$CPUS" \
    "$FFMPEG_SNAPSHOT" "$SKIP_VVDEC" "$FFMPEG_LIB_FLAGS" "$ENABLE_FFMPEG_PGO" "$OS_NAME" > "$LOG_DIR/build-ffmpeg.log" 2>&1
checkStatus $? "build ffmpeg failed. Check $LOG_DIR/build-ffmpeg.log and potentially $SOURCE_DIR/ffmpeg/ffbuild/config.log"
echoDurationInSections $START_TIME

echoSection "Compilation finished successfully"
echoDurationInSections $COMPILATION_START_TIME


# --- Post-Build Steps (OS Specific) ---
if [ "$OS_NAME" = "Darwin" ]; then
    echoSection "Relocate dylibs (macOS)"
    START_TIME=$(currentTimeInSeconds)
    relocateDylib # Function defined in functions.sh (needs merging)
    checkStatus $? "relocating dylibs failed"
    echoDurationInSections $START_TIME
fi


# --- Bundle Result ---
if [ "$SKIP_BUNDLE" = "NO" ]; then
    echoSection "Bundle result into tar.gz (Linux) or zip (macOS)"
    echo "DEBUG: Checking contents of OUT_DIR ($OUT_DIR) before bundling:"
    ls -lA "$OUT_DIR"
    echo "-------------------------------------------"
    if [ -z "$(ls -A "$OUT_DIR")" ]; then
        echo "ERROR: OUT_DIR ($OUT_DIR) is empty or does not exist. Skipping bundling."
    else
        BUNDLE_FILENAME=""
        BUNDLE_CMD=""
        if [ "$OS_NAME" = "Darwin" ]; then
            BUNDLE_FILENAME="ffmpeg-build-macos.zip"
            BUNDLE_CMD="zip -9 -r"
             echo "Archiving contents of $OUT_DIR to $BUNDLE_FILENAME..."
            (cd "$OUT_DIR" && $BUNDLE_CMD "$WORKING_DIR/$BUNDLE_FILENAME" .) # Use . to include hidden files if any
        else # Linux
            BUNDLE_FILENAME="ffmpeg-build-linux.tar.gz"
            BUNDLE_CMD="tar -czf"
            echo "Archiving non-hidden contents of $OUT_DIR to $BUNDLE_FILENAME using subshell..."
             (cd "$OUT_DIR" && $BUNDLE_CMD "$WORKING_DIR/$BUNDLE_FILENAME" *) # Use * for non-hidden
        fi

        checkStatus $? "bundling failed"
        echo "DEBUG: Listing contents of created archive:"
        if [ "$OS_NAME" = "Darwin" ]; then
            unzip -l "$WORKING_DIR/$BUNDLE_FILENAME"
        else
            tar -tzf "$WORKING_DIR/$BUNDLE_FILENAME"
        fi
        echo "-------------------------------------------"
    fi
fi


# --- Run Tests ---
if [ "$SKIP_TEST" = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "Run tests"
    if [ -f "$TEST_DIR/test.sh" ]; then
        "$TEST_DIR/test.sh" "$SCRIPT_DIR" "$TEST_DIR" "$TEST_OUT_DIR" "$OUT_DIR" "$LOG_DIR" > "$LOG_DIR/test.log" 2>&1
         TEST_STATUS=$?
         if [ $TEST_STATUS -ne 0 ]; then
            echo "WARNING: Test failed (Exit Code: $TEST_STATUS). Check $LOG_DIR/test.log and $TEST_OUT_DIR/*.log"
            # Decide whether to exit or continue despite test failure
            # exit 1 # Uncomment to make test failures block completion
        else
            echo "Tests executed successfully"
        fi
    else
         echo "Warning: Test script $TEST_DIR/test.sh not found, skipping tests."
    fi
    echoDurationInSections $START_TIME
fi

echo "Build script finished."