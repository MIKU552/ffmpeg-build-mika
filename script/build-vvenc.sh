#!/bin/bash

# ==============================================================================
# Build Script for VVenC (Fraunhofer Versatile Video Encoder)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - H.266/VVC Encoding Support
#   - Profile-Guided Optimization (PGO)
#   - Cross-platform build (Linux GCC / macOS Clang)
# ==============================================================================

# 1. Argument Processing
SCRIPT_DIR="$1"
SOURCE_DIR="$2"
TOOL_DIR="$3"
CPUS="$4"

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

echoSection "Building VVenC"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/vvenc"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

OS_NAME=$(uname -s)

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/vvenc"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
TARBALL="vvenc-${VERSION}.tar.gz"
URL="https://github.com/fraunhoferhhi/vvenc/archive/${VERSION}.tar.gz"
# Note: GitHub archives often drop the 'v' in the folder name inside, e.g., vvenc-1.0.0
# We use --strip-components=1 to be safe.

download "$URL" "$TARBALL"

SRC_DIR_NAME="vvenc-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"
cd "$SRC_DIR_NAME" || exit 1

# 4. PGO Configuration
# ------------------------------------------------------------------------------
# Define flags for PGO instrumentation and usage
PGO_GEN_CFLAGS=""
PGO_GEN_CXXFLAGS=""
PGO_USE_CFLAGS=""
PGO_USE_CXXFLAGS=""
ENABLE_PGO="YES"

# Check for training samples first
SAMPLE_DIR="$SCRIPT_DIR/../sample"
SAMPLES=("stefan_sif.y4m.xz" "taikotemoto.y4m.xz" "720p_bbb.y4m.xz" "4k_bbb.y4m.xz")
for sample in "${SAMPLES[@]}"; do
    if [ ! -f "$SAMPLE_DIR/$sample" ]; then
        echo "Warning: Sample $sample missing. Disabling PGO."
        ENABLE_PGO="NO"
        break
    fi
done

if [ "$OS_NAME" = "Darwin" ]; then
    # macOS (Clang)
    PGO_GEN_FLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PGO_GEN_CFLAGS="$PGO_GEN_FLAGS"
    PGO_GEN_CXXFLAGS="$PGO_GEN_FLAGS"
    
    # Locate llvm-profdata
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA="llvm-profdata"
    else
        XCODE_PATH=$(xcode-select -p 2>/dev/null)
        LLVM_PROFDATA="$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata"
    fi
    
    if [ ! -x "$LLVM_PROFDATA" ] && [ "$ENABLE_PGO" = "YES" ]; then
        echo "Warning: llvm-profdata not found. Disabling PGO."
        ENABLE_PGO="NO"
    fi
else
    # Linux (GCC)
    PGO_GEN_FLAGS="-fprofile-generate"
    PGO_GEN_CFLAGS="$PGO_GEN_FLAGS"
    PGO_GEN_CXXFLAGS="$PGO_GEN_FLAGS"
fi

# 5. PGO Workflow
# ------------------------------------------------------------------------------
if [ "$ENABLE_PGO" = "YES" ]; then
    echoSection "PGO Step 1: Instrumentation"
    
    mkdir -p build-pgo
    # Configure instrumented build
    cmake -S . -B build-pgo -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$(pwd)/install-pgo" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
        -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS"
        
    checkStatus $? "PGO Config failed"
    
    # Build & Install to local temp prefix
    cmake --build build-pgo -j "$CPUS"
    checkStatus $? "PGO Build failed"
    cmake --install build-pgo
    
    echoSection "PGO Step 2: Training"
    # Run the encoder on samples
    APP="./install-pgo/bin/vvencapp"
    
    for sample in "${SAMPLES[@]}"; do
        echo "Training on $sample..."
        # Pipe xz -> vvencapp, discard output bitstream (-o /dev/null)
        xz -dc "$SAMPLE_DIR/$sample" | \
        $APP -i - --y4m --preset fast --frames 100 -o /dev/null
        # Note: Reduced frames/preset for speed, adjust as needed for quality
    done
    
    echoSection "PGO Step 3: Processing Profiles"
    
    if [ "$OS_NAME" = "Darwin" ]; then
        # Merge raw profiles
        $LLVM_PROFDATA merge -o default.profdata ./*.profraw
        checkStatus $? "Profile merge failed"
        
        # Set absolute path for Use flags
        ABS_PROF_PATH="$(pwd)/default.profdata"
        PGO_USE_CFLAGS="-fprofile-use=$ABS_PROF_PATH -Wno-backend-plugin"
        PGO_USE_CXXFLAGS="-fprofile-use=$ABS_PROF_PATH -Wno-backend-plugin"
        
        # Cleanup
        rm ./*.profraw
    else
        # Linux GCC uses .gcda files in-place
        PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile -Wno-coverage-mismatch"
        PGO_USE_CXXFLAGS="-fprofile-use -Wno-missing-profile -Wno-coverage-mismatch"
    fi
    
    # Clean build directory for final build
    rm -rf build-pgo install-pgo
else
    echo "Skipping PGO (Missing samples or tools)."
fi

# 6. Final Build
# ------------------------------------------------------------------------------
echoSection "Final Optimized Build"

mkdir -p build-final
# Configure optimized build
cmake -S . -B build-final -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DVVENC_ENABLE_LINK_TIME_OPT=ON \
    -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
    -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS"

checkStatus $? "Final Config failed"

cmake --build build-final -j "$CPUS"
checkStatus $? "Final Build failed"

echo "Installing VVenC..."
cmake --install build-final
checkStatus $? "Final Install failed"

echoSection "VVenC Build Complete"
