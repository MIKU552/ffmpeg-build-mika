#!/bin/bash

# ==============================================================================
# Build Script for FFmpeg (Shared/Dynamic Library Version)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
# ==============================================================================

# 1. Argument Processing
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
OS_NAME=${10}

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

echoSection "Building FFmpeg (Shared Libs)"

# 2. Version Setup
if [ "$FFMPEG_SNAPSHOT" = "YES" ]; then
    VERSION="snapshot"
    FFMPEG_TARBALL="ffmpeg-snapshot.tar.bz2"
    FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2"
else
    VERSION_FILE="$SCRIPT_DIR/../version/ffmpeg"
    if [ ! -f "$VERSION_FILE" ]; then
        echo "Error: Version file not found."
        exit 1
    fi
    VERSION=$(cat "$VERSION_FILE")
    FFMPEG_TARBALL="ffmpeg-$VERSION.tar.xz"
    FFMPEG_URL="https://ffmpeg.org/releases/$FFMPEG_TARBALL"
fi

echo "FFmpeg Version: $VERSION"
echo "PGO Enabled: $ENABLE_FFMPEG_PGO"

# 3. Source Preparation
cd "$SOURCE_DIR" || exit 1
mkdir -p "ffmpeg"
cd "ffmpeg" || exit 1

FFMPEG_SRC_DIR="ffmpeg-src"

# Download if not present
if [ ! -d "$FFMPEG_SRC_DIR" ]; then
    echo "Downloading FFmpeg source..."
    download "$FFMPEG_URL" "$FFMPEG_TARBALL"
    
    mkdir -p "$FFMPEG_SRC_DIR"
    echo "Unpacking..."
    tar -xf "$FFMPEG_TARBALL" -C "$FFMPEG_SRC_DIR" --strip-components=1
    checkStatus $? "Unpack failed"
    rm "$FFMPEG_TARBALL"
else
    echo "Using existing source directory."
fi

cd "$FFMPEG_SRC_DIR" || exit 1

# 4. Apply Patches (VVDec)
if [ "$SKIP_VVDEC_PATCH" = "NO" ]; then
    echoSection "Applying VVDec Patch"
    PATCH_FILE="libvvdec.patch"
    PATCH_URL="https://raw.githubusercontent.com/wiki/fraunhoferhhi/vvdec/data/patch/v9-libvvdec.patch"
    
    if [ ! -f "$PATCH_FILE" ]; then
        download "$PATCH_URL" "$PATCH_FILE"
    fi

    if patch --forward -p1 < "$PATCH_FILE"; then
        echo "Patch applied successfully."
    else
        echo "Patch skipped (likely already applied)."
    fi

    if [ -f "libavcodec/libvvdec.c" ]; then
        echo "Fixing AV_PROFILE constants in libvvdec.c..."
        run_sed 's/FF_PROFILE_VVC_MAIN_10/AV_PROFILE_VVC_MAIN_10/g' "libavcodec/libvvdec.c"
    fi
fi

# 5. Build Configuration Logic (Strict Ordering)
# ------------------------------------------------------------------------------

# OS-Specific Portable RPATH
PORTABLE_RPATH=""
if [ "$OS_NAME" = "Linux" ]; then
    PORTABLE_RPATH='-Wl,-rpath,'
    PORTABLE_RPATH+=\'
    PORTABLE_RPATH+='\$\$ORIGIN/../lib'
    PORTABLE_RPATH+=\'
fi

# GROUP 1: Extra Flags & Paths (Will appear FIRST in ffmpeg -version)
CONFIG_EXTRAS="--prefix=$OUT_DIR \
    --pkg-config-flags=--static \
    --extra-version=MiKayule-Shared-$(date +%Y%m%d) \
    --extra-cflags=-I$TOOL_DIR/include \
    --extra-ldflags=-L$TOOL_DIR/lib \
    --extra-libs=-lm \
    --extra-libs=-lpthread"

# Only append RPATH if it's not empty (i.e., on Linux)
if [ -n "$PORTABLE_RPATH" ]; then
    CONFIG_EXTRAS="$CONFIG_EXTRAS --extra-ldflags=$PORTABLE_RPATH"
fi

if [ "$OS_NAME" = "Linux" ]; then
    CONFIG_EXTRAS="$CONFIG_EXTRAS --extra-libs=-ldl"
fi

# GROUP 2: Core Build Behaviors (Will appear MIDDLE)
CONFIG_BEHAVIOR="--enable-shared \
    --disable-static \
    --disable-debug \
    --enable-lto \
    --enable-pthreads \
    --enable-pic"

# GROUP 3: Components & Libraries (Will appear LAST)
CONFIG_LIBS="$FFMPEG_LIB_FLAGS"

# Helper function to enforce ordering even when adding PGO dynamic flags
run_configure() {
    local PGO_C="$1"
    local PGO_L="$2"
    local CURRENT_EXTRAS="$CONFIG_EXTRAS"

    # Inject PGO flags into the FIRST group if they exist
    if [ -n "$PGO_C" ]; then CURRENT_EXTRAS="$CURRENT_EXTRAS --extra-cflags=$PGO_C"; fi
    if [ -n "$PGO_L" ]; then CURRENT_EXTRAS="$CURRENT_EXTRAS --extra-ldflags=$PGO_L"; fi

    echo "Executing: ./configure $CURRENT_EXTRAS $CONFIG_BEHAVIOR $CONFIG_LIBS"
    ./configure $CURRENT_EXTRAS $CONFIG_BEHAVIOR $CONFIG_LIBS
}

# 6. PGO Build Loop
# ------------------------------------------------------------------------------

SAMPLE_DIR="$SCRIPT_DIR/../sample"
HAS_SAMPLES="NO"
if [ -d "$SAMPLE_DIR" ] && [ -n "$(find "$SAMPLE_DIR" -maxdepth 1 -name "*.y4m*" -print -quit)" ]; then
    HAS_SAMPLES="YES"
fi

if [ "$ENABLE_FFMPEG_PGO" = "YES" ] && [ "$HAS_SAMPLES" = "YES" ]; then
    # --- PGO PHASE 1: INSTRUMENT ---
    echoSection "PGO Phase 1: Instrumentation"
    make clean >/dev/null 2>&1

    PGO_CFLAGS=""
    PGO_LDFLAGS=""
    if [ "$OS_NAME" = "Darwin" ]; then
        PGO_CFLAGS="-fprofile-instr-generate"
        PGO_LDFLAGS="-fprofile-instr-generate"
    else
        PGO_CFLAGS="-fprofile-generate"
        PGO_LDFLAGS="-fprofile-generate"
    fi

    run_configure "$PGO_CFLAGS" "$PGO_LDFLAGS"
    checkStatus $? "PGO Configure (Instrument) failed"

    echo "Compiling Instrumented FFmpeg..."
    make -j "$CPUS"
    checkStatus $? "PGO Build (Instrument) failed"

    # --- PGO PHASE 2: TRAINING ---
    echoSection "PGO Phase 2: Training"
    
    FFMPEG_BIN="./ffmpeg_g" # Use unstripped binary
    if [ ! -f "$FFMPEG_BIN" ]; then FFMPEG_BIN="./ffmpeg"; fi

    export LD_LIBRARY_PATH="$(pwd)/libavcodec:$(pwd)/libavformat:$(pwd)/libavutil:$(pwd)/libswscale:$(pwd)/libswresample:$(pwd)/libavfilter:$(pwd)/libavdevice:$(pwd)/libpostproc:$LD_LIBRARY_PATH"
    if [ "$OS_NAME" = "Darwin" ]; then
        export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH"
    fi

    echo "Training with samples..."
    for SAMPLE in "$SAMPLE_DIR"/*.y4m*; do
        [ -e "$SAMPLE" ] || continue
        echo "Processing: $(basename "$SAMPLE")"
        if [[ "$SAMPLE" == *.xz ]]; then CAT_CMD="xz -dc"; else CAT_CMD="cat"; fi
        
        $CAT_CMD "$SAMPLE" | $FFMPEG_BIN -y -f yuv4mpegpipe -i - -frames:v 50 -c:v libx264 -preset veryfast -f null - >/dev/null 2>&1
    done

    if [ "$OS_NAME" = "Darwin" ]; then
        llvm-profdata merge -o default.profdata default.profraw
        rm default.profraw
    fi

    # --- PGO PHASE 3: USE ---
    echoSection "PGO Phase 3: Final Optimized Build"
    make clean >/dev/null 2>&1

    PGO_USE_CFLAGS=""
    if [ "$OS_NAME" = "Darwin" ]; then
        PGO_USE_CFLAGS="-fprofile-instr-use=default.profdata"
    else
        PGO_USE_CFLAGS="-fprofile-use -fprofile-correction"
    fi

    run_configure "$PGO_USE_CFLAGS" "$PGO_USE_CFLAGS"
    checkStatus $? "PGO Configure (Use) failed"

else
    # --- STANDARD BUILD ---
    echoSection "Standard Build Configuration"
    run_configure "" ""
    checkStatus $? "Configure failed"
fi

# 7. Final Compilation
echoSection "Compiling Final FFmpeg"
make -j "$CPUS"
checkStatus $? "Final Make failed"

# 8. Install
echoSection "Installing"
make install
checkStatus $? "Install failed"

echoSection "FFmpeg Build Successful!"
echo "Dynamic libraries installed to: $OUT_DIR/lib"
echo "Executable installed to: $OUT_DIR/bin"