#!/bin/bash

# ==============================================================================
# Build Script for SVT-AV1 (Scalable Video Technology for AV1)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - Supports building from specific Git Commit Hash or Release Tag
#   - Automated PGO (Profile-Guided Optimization)
#   - Cross-platform patching (Linux/macOS)
# ==============================================================================

# 1. Argument Processing
echo "Arguments: $@"
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

echoSection "Building SVT-AV1"

# 2. Load Commit Hash / Version
# The file 'version/svt-av1' should contain the full Commit Hash or Tag (e.g., v1.8.0)
VERSION_FILE="$SCRIPT_DIR/../version/svt-av1"
if [ -f "$VERSION_FILE" ]; then
    COMMIT_ID=$(cat "$VERSION_FILE")
    # Trim whitespace just in case
    COMMIT_ID=$(echo "$COMMIT_ID" | xargs)
else
    echo "Error: Version file not found at $VERSION_FILE"
    exit 1
fi

echo "Target Commit/Tag: $COMMIT_ID"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/svt-av1"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# GitLab Archive URL pattern works for both tags and commit hashes:
TARBALL="SVT-AV1-${COMMIT_ID}.tar.gz"
URL="https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/${COMMIT_ID}/SVT-AV1-${COMMIT_ID}.tar.gz"

download "$URL" "$TARBALL"

# 4. Unpack
# CRITICAL: We use --strip-components=1 because the top-level folder name 
# changes based on commit hash.
tar -zxf "$TARBALL" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 5. Apply Patches for PGO Training
# ------------------------------------------------------------------------------
# We modify 'pgohelper.cmake' to allow piping compressed video (.y4m.xz) 
# into the encoder, saving disk space during the PGO training phase.

PGO_CMAKE_FILE="Build/pgohelper.cmake"
echo "Patching $PGO_CMAKE_FILE for compressed training assets..."

if [ -f "$PGO_CMAKE_FILE" ]; then
    # 1. Update extension check from .y4m to .y4m.xz
    run_sed 's/\.y4m/.y4m.xz/g' "$PGO_CMAKE_FILE"

    # 2. Inject 'xz -dc |' pipe
    # Finds the line executing SvtAv1EncApp and prepends the decompression command
    # Matches: ${SvtAv1EncApp} -i ${video} ...
    # Note: We match strictly to ensure we are patching the command execution line
    run_sed 's/\${SvtAv1EncApp} -i \${video}/xz -dc \${video} | \${SvtAv1EncApp} -i -/g' "$PGO_CMAKE_FILE"

    # 3. Add --lookahead 120 (Recommended for PGO quality)
    run_sed 's/--film-grain 8/--film-grain 8 --lookahead 120/g' "$PGO_CMAKE_FILE"
    
    # 4. Wrap command in 'sh -c' to support pipes if on Linux/Unix
    # This allows the pipe | character to function within the cmake execute_process
    run_sed 's/\${ENCODING_COMMAND}/sh -c "\${ENCODING_COMMAND}"/g' "$PGO_CMAKE_FILE"
    
    checkStatus $? "Patching pgohelper.cmake failed"
else
    echo "Warning: $PGO_CMAKE_FILE not found. If you are on a very new commit, the file structure might have changed."
fi

# macOS Specific Configurations
OS_NAME=$(uname -s)
LLVM_PROFDATA_FLAG=""

if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS Clang PGO configurations..."
    
    # Patch CMakeLists.txt to increase PGO counters (prevents overflow on huge codebases)
    if [ -f "CMakeLists.txt" ]; then
        run_sed 's/PGO_DIR}/PGO_DIR} -mllvm -vp-counters-per-site=4096/g' CMakeLists.txt
    fi
    
    # Locate llvm-profdata for merging profiles
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA_FLAG="-DLLVM_PROFDATA=$(command -v llvm-profdata)"
        echo "Found llvm-profdata in PATH"
    else
        # Fallback to Xcode path
        XCODE_PATH=$(xcode-select -p 2>/dev/null)
        if [ -n "$XCODE_PATH" ] && [ -x "$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata" ]; then
            LLVM_PROFDATA_FLAG="-DLLVM_PROFDATA=$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata"
            echo "Found llvm-profdata via Xcode"
        else
            echo "Warning: llvm-profdata not found. PGO build might fail."
        fi
    fi
fi

# 6. Configure
# ------------------------------------------------------------------------------
# Create a separate build directory (standard CMake practice)
mkdir -p build
cd build || exit 1

echo "Configuring CMake..."

# Notes:
# - BUILD_SHARED_LIBS=OFF: Static linking is required for our FFmpeg build.
# - SVT_AV1_PGO=ON: Enables the 'RunPGO' target.
# - SVT_AV1_LTO=ON: Link Time Optimization for performance.
# - BUILD_APPS=ON: REQUIRED for PGO. The encoder binary is needed to run the profile training.
# shellcheck disable=SC2086
cmake \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_APPS=ON \
    -DSVT_AV1_LTO=ON \
    -DSVT_AV1_PGO=ON \
    -DSVT_AV1_PGO_CUSTOM_VIDEOS="$SCRIPT_DIR/../sample" \
    $LLVM_PROFDATA_FLAG \
    ..

checkStatus $? "CMake Configuration failed"

# 7. Execute PGO Training
# ------------------------------------------------------------------------------
echoSection "Running PGO Training (make RunPGO)"
echo "Compiling instrumented encoder -> Running training videos -> Compiling optimized encoder"

# 'RunPGO' target handles the entire Generate -> Train -> Use cycle
make RunPGO -j "$CPUS"
checkStatus $? "PGO Training failed"

# 8. Install
# ------------------------------------------------------------------------------
echoSection "Installing SVT-AV1"
# This will install headers, libs, AND the SvtAv1EncApp binary.
# FFmpeg will only use the headers and .a library.
make install
checkStatus $? "Installation failed"

echoSection "SVT-AV1 Build Complete"