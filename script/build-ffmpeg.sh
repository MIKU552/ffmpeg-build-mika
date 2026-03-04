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
    PATCH_URL="https://raw.githubusercontent.com/wiki/fraunhoferhhi/vvdec/data/patch/v6-0001-avcodec-add-external-dec-libvvdec-for-H266-VVC.patch"
    
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

# 5. Build Configuration Logic (For Dynamic Libraries)
# ------------------------------------------------------------------------------

# Basic Flags changes:
# --enable-shared: Build .so/.dylib files.
# --disable-static: Don't build .a files for FFmpeg itself.
# --extra-cflags=-fPIC: Crucial when linking static dependencies into a shared lib.
BASE_ARGS="--prefix=$OUT_DIR \
    --pkg-config-flags=--static \
    --enable-shared \
    --disable-static \
    --disable-debug \
    --enable-lto \
    --enable-pthreads \
    --enable-version3 \
    --enable-pic \
    --extra-version=MiKayule-Shared-$(date +%Y%m%d)"

# Paths
PATH_ARGS="--extra-cflags=-I$TOOL_DIR/include \
    --extra-ldflags=-L$TOOL_DIR/lib"

# Libraries
LIB_ARGS="$FFMPEG_LIB_FLAGS"

# RPATH Settings (CRITICAL for Shared Builds)
# This ensures the 'ffmpeg' binary knows where to look for libavcodec.so at runtime
# without needing to set LD_LIBRARY_PATH environment variable.
if [ "$OS_NAME" = "Darwin" ]; then
    # macOS: Use @loader_path or absolute path
    # We use the install prefix lib dir
    RPATH_FLAGS="-Wl,-rpath,$OUT_DIR/lib"
else
    # Linux: Use $ORIGIN or absolute path
    RPATH_FLAGS="-Wl,-rpath,$OUT_DIR/lib"
fi

# Extra Linker Flags
# -lm, -lpthread are standard.
EXTRA_LIBS="--extra-libs=-lm --extra-libs=-lpthread"
if [ "$OS_NAME" = "Linux" ]; then
    EXTRA_LIBS="$EXTRA_LIBS --extra-libs=-ldl"
fi

# Combine all arguments
# Note: We add RPATH_FLAGS to extra-ldflags
CONFIGURE_CMD="./configure $BASE_ARGS $PATH_ARGS $LIB_ARGS $EXTRA_LIBS --extra-ldflags=$RPATH_FLAGS"


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

    # IMPORTANT: For shared builds, we must ensure PGO flags are passed to both CFLAGS and LDFLAGS
    $CONFIGURE_CMD \
        --extra-cflags="$PGO_CFLAGS" \
        --extra-ldflags="$PGO_LDFLAGS"
    
    checkStatus $? "PGO Configure (Instrument) failed"

    echo "Compiling Instrumented FFmpeg..."
    make -j "$CPUS"
    checkStatus $? "PGO Build (Instrument) failed"

    # --- PGO PHASE 2: TRAINING ---
    echoSection "PGO Phase 2: Training"
    
    FFMPEG_BIN="./ffmpeg_g" # Use unstripped binary
    if [ ! -f "$FFMPEG_BIN" ]; then FFMPEG_BIN="./ffmpeg"; fi

    # For shared builds during PGO training, we usually need LD_LIBRARY_PATH
    # because the libraries are in the build tree, not installed yet.
    export LD_LIBRARY_PATH="$(pwd)/libavcodec:$(pwd)/libavformat:$(pwd)/libavutil:$(pwd)/libswscale:$(pwd)/libswresample:$(pwd)/libavfilter:$(pwd)/libavdevice:$(pwd)/libpostproc:$LD_LIBRARY_PATH"
    if [ "$OS_NAME" = "Darwin" ]; then
        export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH"
    fi

    echo "Training with samples..."
    for SAMPLE in "$SAMPLE_DIR"/*.y4m*; do
        [ -e "$SAMPLE" ] || continue
        echo "Processing: $(basename "$SAMPLE")"
        if [[ "$SAMPLE" == *.xz ]]; then CAT_CMD="xz -dc"; else CAT_CMD="cat"; fi
        
        # Training Run
        $CAT_CMD "$SAMPLE" | $FFMPEG_BIN -y -f yuv4mpegpipe -i - -frames:v 50 -c:v libx264 -preset veryfast -f null - >/dev/null 2>&1
    done

    # Merge Profile Data (macOS only)
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

    $CONFIGURE_CMD \
        --extra-cflags="$PGO_USE_CFLAGS" \
        --extra-ldflags="$PGO_USE_CFLAGS"
        
    checkStatus $? "PGO Configure (Use) failed"

else
    # --- STANDARD BUILD ---
    echoSection "Standard Build Configuration"
    $CONFIGURE_CMD
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