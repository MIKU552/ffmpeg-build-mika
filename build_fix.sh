#!/bin/bash

# ==============================================================================
# FFmpeg Cross-Platform Build Script (Linux & macOS)
# ==============================================================================
# Refactored and Optimized
# Based on original works by Martin Riedl & Hayden Zheng
#
# Description:
#   This script automates the fetching, compiling, and linking of FFmpeg
#   and its dependencies. It supports incremental builds and cross-platform
#   logic for Linux (Debian/Ubuntu) and macOS (Apple Silicon/Intel).
#
# License: Apache License, Version 2.0
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Initialization & OS Detection
# ------------------------------------------------------------------------------

# Exit on error in pipes (optional, strictly speaking safer but can be disabled if needed)
set -o pipefail

# Detect Operating System
OS_NAME="$(uname -s)"
echo "Detected OS: ${OS_NAME}"

# ------------------------------------------------------------------------------
# 2. Default Configuration & Feature Flags
# ------------------------------------------------------------------------------

# --- General Behavior ---
SKIP_BUNDLE="YES"           # Skip packing the result into .tar.gz/.zip
SKIP_TEST="NO"              # Skip running post-build tests
FORCE_REBUILD="NO"          # Force clean and rebuild of targets
CPU_LIMIT=""                # Manually limit CPU threads (default: auto-detect)
FFMPEG_SNAPSHOT="YES"       # Build latest snapshot vs specific release
ENABLE_FFMPEG_PGO="NO"      # Profile-Guided Optimization

# --- Foundation & Tools ---
SKIP_NASM="NO"
SKIP_PKG_CONFIG="YES"       # Usually use system pkg-config
SKIP_ZLIB="NO"
SKIP_OPENSSL="NO"
SKIP_CMAKE="NO"
SKIP_NINJA="NO"
SKIP_SDL="NO"               # Required for ffplay

# --- Text, Subtitles & Filters ---
SKIP_FRIBIDI="NO"
SKIP_FREETYPE="NO"
SKIP_FONTCONFIG="NO"
SKIP_HARFBUZZ="NO"
SKIP_LIBASS="NO"
SKIP_LIBXML2="NO"
SKIP_LIBBLURAY="NO"
SKIP_SNAPPY="NO"
SKIP_SRT="NO"
SKIP_LIBVMAF="NO"
SKIP_ZIMG="NO"
SKIP_ZVBI="NO"
SKIP_LIBKLVANC="NO"
SKIP_DECKLINK="YES"         # Defaults to YES (Requires SDK)

# --- Video Codecs ---
SKIP_AOM="NO"               # AV1
SKIP_DAV1D="NO"             # AV1 Decoder
SKIP_RAV1E="NO"             # AV1 Encoder (Rust)
SKIP_SVT_AV1="NO"           # AV1 Encoder (Intel)
SKIP_VPX="NO"               # VP8/VP9
SKIP_LIBWEBP="NO"           # WebP
SKIP_X264="NO"              # H.264
SKIP_OPEN_H264="NO"         # H.264 (Cisco)
SKIP_X265="NO"              # H.265 (HEVC)
SKIP_X265_MULTIBIT="NO"     # H.265 10/12bit
SKIP_VVDEC="NO"             # H.266 (VVC) Decoder
SKIP_VVENC="NO"             # H.266 (VVC) Encoder
SKIP_LIBTHEORA="NO"
SKIP_OPEN_JPEG="NO"

# --- Audio Codecs ---
SKIP_LAME="NO"              # MP3
SKIP_OPUS="NO"
SKIP_LIBVORBIS="NO"
SKIP_LIBOGG="NO"
SKIP_FDK_AAC="NO"
SKIP_WHISPER="NO"           # AI Speech-to-Text

# --- Special Options ---
DECKLINK_SDK=""             # Path to Blackmagic Decklink SDK

# ------------------------------------------------------------------------------
# 3. Argument Parsing
# ------------------------------------------------------------------------------

for arg in "$@"; do
    KEY=${arg%%=*}
    VALUE=${arg#*=}
    case $KEY in
        # Behavior
        -SKIP_BUNDLE)       SKIP_BUNDLE=$VALUE ;;
        -SKIP_TEST)         SKIP_TEST=$VALUE ;;
        -FORCE_REBUILD)     FORCE_REBUILD=$VALUE ;;
        -CPU_LIMIT)         CPU_LIMIT=$VALUE ;;
        -FFMPEG_SNAPSHOT)   FFMPEG_SNAPSHOT=$VALUE ;;
        -ENABLE_FFMPEG_PGO) ENABLE_FFMPEG_PGO=$VALUE ;;
        
        # Tools & Libs
        -SKIP_NASM)         SKIP_NASM=$VALUE ;;
        -SKIP_PKG_CONFIG)   SKIP_PKG_CONFIG=$VALUE ;;
        -SKIP_CMAKE)        SKIP_CMAKE=$VALUE ;;
        -SKIP_NINJA)        SKIP_NINJA=$VALUE ;;
        -SKIP_ZLIB)         SKIP_ZLIB=$VALUE ;;
        -SKIP_OPENSSL)      SKIP_OPENSSL=$VALUE ;;
        -SKIP_SDL)          SKIP_SDL=$VALUE ;;
        
        # Video
        -SKIP_X264)         SKIP_X264=$VALUE ;;
        -SKIP_X265)         SKIP_X265=$VALUE ;;
        -SKIP_X265_MULTIBIT) SKIP_X265_MULTIBIT=$VALUE ;;
        -SKIP_AOM)          SKIP_AOM=$VALUE ;;
        -SKIP_DAV1D)        SKIP_DAV1D=$VALUE ;;
        -SKIP_RAV1E)        SKIP_RAV1E=$VALUE ;;
        -SKIP_SVT_AV1)      SKIP_SVT_AV1=$VALUE ;;
        -SKIP_VPX)          SKIP_VPX=$VALUE ;;
        -SKIP_VVENC)        SKIP_VVENC=$VALUE ;;
        -SKIP_VVDEC)        SKIP_VVDEC=$VALUE ;;
        
        # Audio & Others
        -SKIP_LAME)         SKIP_LAME=$VALUE ;;
        -SKIP_OPUS)         SKIP_OPUS=$VALUE ;;
        -SKIP_FDK_AAC)      SKIP_FDK_AAC=$VALUE ;;
        -SKIP_DECKLINK)     SKIP_DECKLINK=$VALUE ;;
        -DECKLINK_SDK)      DECKLINK_SDK=$VALUE ;;
        
        # Catch-all for other skips (simple string matching for brevity)
        -SKIP_*) 
            # Dynamically set variable based on argument name
            VAR_NAME=${KEY#-}
            declare "$VAR_NAME=$VALUE"
            ;;
            
        *) echo "Warning: Unknown argument: $arg" ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. Directory & Workspace Setup
# ------------------------------------------------------------------------------

BASE_DIR="$( cd "$( dirname "$0" )" > /dev/null 2>&1 && pwd )"
SCRIPT_DIR="${BASE_DIR}/script"
WORKING_DIR="$( pwd )"
SOURCE_DIR="$WORKING_DIR/source"
LOG_DIR="$WORKING_DIR/log"
TOOL_DIR="$WORKING_DIR/tool"
OUT_DIR="$WORKING_DIR/out"

# Define Test Directories
if [ "$SKIP_TEST" = "NO" ]; then
    TEST_DIR="${BASE_DIR}/test"
    TEST_OUT_DIR="$WORKING_DIR/test"
fi

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    # shellcheck source=./script/functions.sh
    . "$SCRIPT_DIR/functions.sh"
else
    echo "ERROR: functions.sh not found in $SCRIPT_DIR"
    exit 1
fi

echoSection "Prepare Workspace"
echo "Root Directory: $WORKING_DIR"

# Create Directories
mkdir -p "$SOURCE_DIR" "$LOG_DIR" "$OUT_DIR"
mkdir -p "$TOOL_DIR/bin" "$TOOL_DIR/include" "$TOOL_DIR/lib/pkgconfig"

# Linux often uses lib64, create it to be safe
if [ "$OS_NAME" = "Linux" ]; then
    mkdir -p "$TOOL_DIR/lib64/pkgconfig"
fi

if [ "$SKIP_TEST" = "NO" ]; then
    mkdir -p "$TEST_OUT_DIR"
fi

# ------------------------------------------------------------------------------
# 5. Environment Variables & Compiler Flags
# ------------------------------------------------------------------------------

echoSection "Setup Build Environment ($OS_NAME)"

# Compiler Setup
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Configuring for macOS (Clang/Xcode)..."
    # macOS usually auto-detects clang
else
    echo "Configuring for Linux (GCC)..."
    export CC=gcc
    export CXX=g++
    export AR=ar
    export NM=nm
    export RANLIB=ranlib
    export LD=ld
fi

# Flags setup
PIC_FLAG=""
if [ "$OS_NAME" = "Linux" ]; then
    PIC_FLAG="-fPIC"
fi

# Path Construction
INCLUDE_PATH="-I${TOOL_DIR}/include"
LIB_PATH="-L${TOOL_DIR}/lib"
PKG_PATH="${TOOL_DIR}/lib/pkgconfig"

if [ "$OS_NAME" = "Linux" ]; then
    LIB_PATH="$LIB_PATH -L${TOOL_DIR}/lib64"
    PKG_PATH="$PKG_PATH:${TOOL_DIR}/lib64/pkgconfig"
fi

# Export Global Variables
export CFLAGS="$INCLUDE_PATH $PIC_FLAG"
export CPPFLAGS="$INCLUDE_PATH $PIC_FLAG"
export CXXFLAGS="$INCLUDE_PATH $PIC_FLAG"
export LDFLAGS="$LIB_PATH"
export PKG_CONFIG_PATH="$PKG_PATH:${PKG_CONFIG_PATH:-}"
export PATH="$TOOL_DIR/bin:$PATH"

echo "CFLAGS: $CFLAGS"
echo "LDFLAGS: $LDFLAGS"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

# CPU Thread Detection
if [ -n "$CPU_LIMIT" ]; then
    CPUS=$CPU_LIMIT
else
    if [ "$OS_NAME" = "Darwin" ]; then
        CPUS=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    else
        CPUS=$(nproc 2>/dev/null || echo 1)
    fi
fi
echo "Using $CPUS CPU threads."

# ------------------------------------------------------------------------------
# 6. Core Build Function
# ------------------------------------------------------------------------------

FFMPEG_LIB_FLAGS=""
REQUIRES_GPL="NO"
REQUIRES_NON_FREE="NO"

# Docstring: run_build
# --------------------
# Compiles a dependency if it doesn't already exist in the tool directory.
#
# Arguments:
#   $1 - libname:             Unique identifier for the library (e.g., "x264").
#   $2 - script_name:         The shell script file name in /script/ (e.g., "build-x264").
#   $3 - check_filename:      The artifact to check for existence (e.g., "libx264.a" or "bin/nasm").
#   $4 - source_subdir:       Subdirectory name in /source/ to unpack code into.
#   $5 - ffmpeg_flag:         Flag to append to FFmpeg config (e.g., "--enable-libx264").
#   $6 - is_gpl:              "YES" if this lib triggers GPL requirement.
#   $7 - is_nonfree:          "YES" if this lib triggers Non-Free requirement.
#   $@ - extra_args:          Additional arguments passed to the build script.
run_build() {
    local libname=$1
    local script_name=$2
    local check_filename=$3
    local source_subdir=$4
    local ffmpeg_flag=$5
    local is_gpl=$6
    local is_nonfree=$7
    shift 7
    local extra_args=("$@")

    # 1. Check if User Skipped
    # Convert libname to UPPERCASE (e.g., x264 -> SKIP_X264)
    local var_name="SKIP_$(echo "$libname" | tr '[:lower:]-' '[:upper:]_')"
    local skip_value="${!var_name}" # Indirect variable reference (bash feature)
    
    # Fallback for old bash/sh if indirect reference fails or is empty
    if [ -z "$skip_value" ]; then
         skip_value=$(eval echo "\$$var_name")
    fi

    if [ "$skip_value" = "YES" ]; then
        echoSection "Skip $libname (User Requested)"
        echo "YES" > "$LOG_DIR/skip-$libname"
        return
    fi

    # 2. Determine Search Paths for Artifacts
    local check_paths=()
    local target_path_lib="$TOOL_DIR/lib/$check_filename"
    local target_path_bin="$TOOL_DIR/bin/$check_filename"
    
    # Heuristic: Check bin/ if it looks like an executable, else check lib/
    if [[ "$libname" == "nasm" || "$libname" == "cmake" || "$libname" == "ninja" || "$libname" == "pkg-config" ]]; then
        check_paths+=("$target_path_bin")
    elif [[ "$libname" == "decklink" ]]; then
        check_paths+=("$TOOL_DIR/include/$check_filename")
    else
        # Default Library Check
        check_paths+=("$target_path_lib")
        if [ "$OS_NAME" = "Linux" ]; then
            check_paths+=("$TOOL_DIR/lib64/$check_filename")
        fi
    fi

    # 3. Check for Existing Artifacts (Incremental Build)
    local should_build="YES"
    local found_at=""

    if [ "$FORCE_REBUILD" != "YES" ]; then
        for path in "${check_paths[@]}"; do
            if [ -e "$path" ]; then
                should_build="NO"
                found_at="$path"
                break
            fi
        done
    fi

    # 4. Execute Build
    if [ "$should_build" = "YES" ]; then
        echoSection "Building $libname..."
        
        # Clean source directory
        rm -rf "$SOURCE_DIR/$source_subdir"
        
        local start_t=$(currentTimeInSeconds)
        
        # Execute the specific build script
        "$SCRIPT_DIR/$script_name.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$CPUS" "${extra_args[@]}" > "$LOG_DIR/${script_name}.log" 2>&1
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo "ERROR: Build failed for $libname. See log: $LOG_DIR/${script_name}.log"
            tail -n 20 "$LOG_DIR/${script_name}.log"
            exit 1
        fi

        # Verify artifact creation
        local verified="NO"
        # If checks were empty, assume success (edge case), else check again
        if [ ${#check_paths[@]} -eq 0 ]; then verified="YES"; fi
        for path in "${check_paths[@]}"; do
            if [ -e "$path" ]; then verified="YES"; break; fi
        done

        if [ "$verified" = "NO" ]; then
            echo "ERROR: Build script finished but artifact not found: $check_filename"
            exit 1
        fi
        
        echoDurationInSections $start_t
    else
        echoSection "Skip $libname (Already exists at $found_at)"
    fi

    # 5. Update FFmpeg Config Flags
    if [ -n "$ffmpeg_flag" ]; then
        FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS $ffmpeg_flag"
    fi
    [ "$is_gpl" = "YES" ] && REQUIRES_GPL="YES"
    [ "$is_nonfree" = "YES" ] && REQUIRES_NON_FREE="YES"
    
    echo "NO" > "$LOG_DIR/skip-$libname"
}

# ------------------------------------------------------------------------------
# 6.5. Prepare PGO Sample Files
# ------------------------------------------------------------------------------
SAMPLE_DIR="${BASE_DIR}/sample"
mkdir -p "$SAMPLE_DIR"
echoSection "Downloading PGO sample files to $SAMPLE_DIR"

DOWNLOAD_URLS=(
    "https://driveshare.miku552.top/0:/dev/ffbuild/4k_bbb.y4m.xz"
    "https://driveshare.miku552.top/0:/dev/ffbuild/720p_bbb.y4m.xz"
    "https://driveshare.miku552.top/0:/dev/ffbuild/stefan_sif.y4m.xz"
    "https://driveshare.miku552.top/0:/dev/ffbuild/taikotemoto.y4m.xz"
)

FAKE_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
MAX_RETRIES=5

for url in "${DOWNLOAD_URLS[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "$SAMPLE_DIR/$filename" ]; then
        echo "Downloading $filename..."
        
        RETRY_COUNT=0
        DOWNLOAD_SUCCESS="NO"
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            EXIT_CODE=0
            
            # Try wget first, then curl
            if command -v wget >/dev/null 2>&1; then
                # wget: -t 3 (internal retries), -c (continue), -q (quiet)
                wget -q -c -t 3 -U "$FAKE_UA" -O "$SAMPLE_DIR/$filename" "$url"
                EXIT_CODE=$?
            elif command -v curl >/dev/null 2>&1; then
                # curl: --retry 3, -C - (continue), -s (silent)
                curl -fL -s --retry 3 -C - -A "$FAKE_UA" -o "$SAMPLE_DIR/$filename" "$url"
                EXIT_CODE=$?
            else
                echo "ERROR: Neither wget nor curl found. Cannot download $filename."
                exit 1
            fi
            
            # Check exit code of the download command, NOT the command -v check
            if [ $EXIT_CODE -eq 0 ]; then
                DOWNLOAD_SUCCESS="YES"
                break # Download successful, break retry loop
            else
                RETRY_COUNT=$((RETRY_COUNT+1))
                echo "WARNING: Download failed for $filename (Code: $EXIT_CODE). Retrying ($RETRY_COUNT/$MAX_RETRIES) in 5 seconds..."
                sleep 5
            fi
        done
        
        if [ "$DOWNLOAD_SUCCESS" = "NO" ]; then
            echo "ERROR: Failed to download $filename after $MAX_RETRIES attempts. Please check network or URL."
            exit 1
        fi
    else
        echo "Found $filename, skipping download."
    fi
done


# ------------------------------------------------------------------------------
# 7. Dependency Build Execution
# ------------------------------------------------------------------------------
COMPILATION_START_TIME=$(currentTimeInSeconds)

# --- Group 1: Build Tools ---
run_build "nasm"       "build-nasm"       "nasm"       "nasm"       "" "NO" "NO"
run_build "pkg-config" "build-pkg-config" "pkg-config" "pkg-config" "" "NO" "NO" "$TOOL_DIR"
run_build "cmake"      "build-cmake"      "cmake"      "cmake"      "" "NO" "NO"
run_build "ninja"      "build-ninja"      "ninja"      "ninja"      "" "NO" "NO"

# --- Group 2: Core Libraries ---
run_build "zlib"       "build-zlib"       "libz.a"     "zlib"       "--enable-zlib" "NO" "NO"
run_build "openssl"    "build-openssl"    "libssl.a"   "openssl"    "--enable-openssl" "NO" "NO"
run_build "libxml2"    "build-libxml2"    "libxml2.a"  "libxml2"    "--enable-libxml2" "NO" "NO"

# --- Group 3: Subtitles & Text ---
run_build "fribidi"    "build-fribidi"    "libfribidi.a"   "fribidi"    "--enable-libfribidi" "NO" "NO"
run_build "freetype"   "build-freetype"   "libfreetype.a"  "freetype"   "--enable-libfreetype" "NO" "NO"
run_build "fontconfig" "build-fontconfig" "libfontconfig.a" "fontconfig" "--enable-fontconfig" "NO" "NO"
run_build "harfbuzz"   "build-harfbuzz"   "libharfbuzz.a"  "harfbuzz"   "--enable-libharfbuzz" "NO" "NO"
run_build "libass"     "build-libass"     "libass.a"       "libass"     "--enable-libass" "NO" "NO"

# --- Group 4: Media Containers & Filters ---
# SDL Check: Static lib name differs on OS? Usually libSDL2.a works for static builds.
run_build "sdl"        "build-sdl"        "libSDL2.a"      "sdl"        "" "NO" "NO"
run_build "libbluray"  "build-libbluray"  "libbluray.a"    "libbluray"  "--enable-libbluray" "NO" "NO"
run_build "snappy"     "build-snappy"     "libsnappy.a"    "snappy"     "--enable-libsnappy" "NO" "NO"
run_build "srt"        "build-srt"        "libsrt.a"       "srt"        "--enable-libsrt" "NO" "NO"
run_build "libvmaf"    "build-libvmaf"    "libvmaf.a"      "libvmaf"    "--enable-libvmaf" "NO" "NO"
run_build "zimg"       "build-zimg"       "libzimg.a"      "zimg"       "--enable-libzimg" "NO" "NO"
run_build "zvbi"       "build-zvbi"       "libzvbi.a"      "zvbi"       "--enable-libzvbi" "NO" "NO"
run_build "libklvanc"  "build-libklvanc"  "libklvanc.a"    "libklvanc"  "--enable-libklvanc" "NO" "NO"

# --- Group 5: Video Codecs ---
run_build "aom"        "build-aom"        "libaom.a"       "aom"        "--enable-libaom" "NO" "NO"
run_build "dav1d"      "build-dav1d"      "libdav1d.a"     "dav1d"      "--enable-libdav1d" "NO" "NO"
run_build "openh264"   "build-openh264"   "libopenh264.a"  "openh264"   "--enable-libopenh264" "NO" "NO"
run_build "openJPEG"   "build-openjpeg"   "libopenjp2.a"   "openjpeg"   "--enable-libopenjpeg" "NO" "NO"
run_build "rav1e"      "build-rav1e"      "librav1e.a"     "rav1e"      "--enable-librav1e" "NO" "NO"
run_build "svt-av1"    "build-svt-av1"    "libSvtAv1Enc.a" "svt-av1"    "--enable-libsvtav1" "NO" "NO"
run_build "vpx"        "build-vpx"        "libvpx.a"       "vpx"        "--enable-libvpx" "NO" "NO"
run_build "libwebp"    "build-libwebp"    "libwebp.a"      "libwebp"    "--enable-libwebp" "NO" "NO"
run_build "x264"       "build-x264"       "libx264.a"      "x264"       "--enable-libx264" "YES" "NO"
run_build "x265"       "build-x265"       "libx265.a"      "x265"       "--enable-libx265" "YES" "NO" "$SKIP_X265_MULTIBIT"
run_build "vvenc"      "build-vvenc"      "libvvenc.a"     "vvenc"      "--enable-libvvenc" "NO" "NO"
run_build "vvdec"      "build-vvdec"      "libvvdec.a"     "vvdec"      "--enable-libvvdec" "NO" "NO"

# --- Group 6: Audio Codecs ---
run_build "libogg"     "build-libogg"     "libogg.a"       "libogg"     "" "NO" "NO"
run_build "libvorbis"  "build-libvorbis"  "libvorbis.a"    "libvorbis"  "--enable-libvorbis" "NO" "NO"
run_build "libtheora"  "build-libtheora"  "libtheora.a"    "libtheora"  "--enable-libtheora" "NO" "NO"
run_build "soxr"       "build-soxr"       "libsoxr.a"      "soxr"       "--enable-libsoxr" "NO" "NO"
run_build "lame"       "build-lame"       "libmp3lame.a"   "lame"       "--enable-libmp3lame" "NO" "NO"
run_build "opus"       "build-opus"       "libopus.a"      "opus"       "--enable-libopus" "NO" "NO"
run_build "fdk-aac"    "build-fdk-aac"    "libfdk-aac.a"   "fdk-aac"    "--enable-libfdk-aac" "NO" "YES"
run_build "whisper"    "build-whisper"    "libwhisper.a"   "whispercpp" "--enable-whisper" "NO" "NO"

# --- Group 7: Hardware & SDKs ---
if [ "$SKIP_DECKLINK" = "NO" ]; then
    if [ -z "$DECKLINK_SDK" ]; then
        echo "ERROR: Decklink requested but SDK path not provided (-DECKLINK_SDK=...)"
        exit 1
    fi
    # Decklink is header-only / shared linking usually, check for header
    run_build "decklink" "build-decklink" "DeckLinkAPI.h" "" "--enable-decklink" "NO" "YES" "$DECKLINK_SDK"
else
    echo "YES" > "$LOG_DIR/skip-decklink"
fi

# ------------------------------------------------------------------------------
# 8. Final FFmpeg Compilation
# ------------------------------------------------------------------------------

echoSection "Configuring Final FFmpeg Flags"

# Apply License Flags
[ "$REQUIRES_GPL" = "YES" ] && FFMPEG_LIB_FLAGS="--enable-gpl $FFMPEG_LIB_FLAGS"
[ "$REQUIRES_NON_FREE" = "YES" ] && FFMPEG_LIB_FLAGS="--enable-nonfree $FFMPEG_LIB_FLAGS"

# Standard Flags
FFMPEG_LIB_FLAGS="--enable-version3 --enable-demuxer=dash $FFMPEG_LIB_FLAGS"

# OS Specific Hardware Acceleration
if [ "$OS_NAME" = "Darwin" ]; then
    echo "Adding macOS Hardware Acceleration..."
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-videotoolbox --enable-audiotoolbox"
elif [ "$OS_NAME" = "Linux" ]; then
    echo "Adding Linux Hardware Acceleration..."
    FFMPEG_LIB_FLAGS="$FFMPEG_LIB_FLAGS --enable-vaapi --enable-vulkan --enable-libdrm"
fi

echoSection "Compile FFmpeg Core"
FFMPEG_SOURCE_PATH="$SOURCE_DIR/ffmpeg"

# Clean source if PGO or Force Rebuild
if [ "$FORCE_REBUILD" = "YES" ] || [ "$ENABLE_FFMPEG_PGO" = "YES" ]; then
    if [ -d "$FFMPEG_SOURCE_PATH" ]; then
        echo "Cleaning FFmpeg source: $FFMPEG_SOURCE_PATH"
        rm -rf "$FFMPEG_SOURCE_PATH"
    fi
fi

# Call build-ffmpeg.sh
"$SCRIPT_DIR/build-ffmpeg.sh" "$SCRIPT_DIR" "$SOURCE_DIR" "$TOOL_DIR" "$OUT_DIR" "$CPUS" \
    "$FFMPEG_SNAPSHOT" "$SKIP_VVDEC" "$FFMPEG_LIB_FLAGS" "$ENABLE_FFMPEG_PGO" "$OS_NAME" > "$LOG_DIR/build-ffmpeg.log" 2>&1

checkStatus $? "FFmpeg build failed! Check $LOG_DIR/build-ffmpeg.log"
echoDurationInSections $COMPILATION_START_TIME

# ------------------------------------------------------------------------------
# 9. Post-Build (Bundle & Test)
# ------------------------------------------------------------------------------

# macOS Dylib Fixup
if [ "$OS_NAME" = "Darwin" ]; then
    echoSection "Relocate Dylibs (macOS)"
    relocateDylib # Assumes this is in functions.sh
    checkStatus $? "Dylib relocation failed"
fi

# Bundling
if [ "$SKIP_BUNDLE" = "NO" ]; then
    echoSection "Bundling Output"
    if [ -z "$(ls -A "$OUT_DIR")" ]; then
        echo "ERROR: Output directory is empty!"
    else
        if [ "$OS_NAME" = "Darwin" ]; then
            BUNDLE_FILE="ffmpeg-build-macos.zip"
            echo "Zipping to $BUNDLE_FILE..."
            (cd "$OUT_DIR" && zip -9 -r "$WORKING_DIR/$BUNDLE_FILE" .)
        else
            BUNDLE_FILE="ffmpeg-build-linux.tar.gz"
            echo "Tarballing to $BUNDLE_FILE..."
            (cd "$OUT_DIR" && tar -czf "$WORKING_DIR/$BUNDLE_FILE" *)
        fi
        echo "Bundle created: $WORKING_DIR/$BUNDLE_FILE"
    fi
fi

# Testing
if [ "$SKIP_TEST" = "NO" ]; then
    echoSection "Running Test Suite"
    if [ -f "$TEST_DIR/test.sh" ]; then
        "$TEST_DIR/test.sh" "$SCRIPT_DIR" "$TEST_DIR" "$TEST_OUT_DIR" "$OUT_DIR" "$LOG_DIR" > "$LOG_DIR/test.log" 2>&1
        if [ $? -ne 0 ]; then
            echo "WARNING: Tests failed. Check $LOG_DIR/test.log"
        else
            echo "Tests passed successfully."
        fi
    else
        echo "Test script not found, skipping."
    fi
fi

echo "=========================================="
echo "   Build Script Completed Successfully"
echo "=========================================="