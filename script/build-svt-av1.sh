#!/bin/bash

# ==============================================================================
# Build Script for SVT-AV1 (Scalable Video Technology for AV1)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - Supports building from specific Git Commit Hash or Release Tag
#   - Automated PGO (Profile-Guided Optimization) tailored to custom params
#   - Robust sample handling (Decompresses samples to avoid CMake pipe errors)
#   - Windows Cross-Compilation with Wine Emulator Bridge
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
VERSION_FILE="$SCRIPT_DIR/../version/svt-av1"
if [ -f "$VERSION_FILE" ]; then
    COMMIT_ID=$(cat "$VERSION_FILE")
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
TARBALL="SVT-AV1-${COMMIT_ID}.tar.gz"
URL="https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/${COMMIT_ID}/SVT-AV1-${COMMIT_ID}.tar.gz"

download "$URL" "$TARBALL"

# 4. Unpack
tar -zxf "$TARBALL" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 5. Prepare PGO Training Data
# ------------------------------------------------------------------------------
PGO_SAMPLE_DIR="$SOURCE_DIR/svt_pgo_samples"
mkdir -p "$PGO_SAMPLE_DIR"

SAMPLE_SOURCE_DIR="$SCRIPT_DIR/../sample"

if [ -d "$SAMPLE_SOURCE_DIR" ]; then
    echo "Preparing PGO training samples (Decompressing)..."
    for f in "$SAMPLE_SOURCE_DIR"/*.xz; do
        if [ -f "$f" ]; then
            filename=$(basename "$f" .xz)
            if [ ! -f "$PGO_SAMPLE_DIR/$filename" ]; then
                echo "Decompressing $filename..."
                xz -d -c "$f" > "$PGO_SAMPLE_DIR/$filename"
            fi
        fi
    done
else
    echo "Warning: Sample directory not found. PGO might fail or be skipped."
fi

# 6. Apply CMake Patches for PGO Parameters
# ------------------------------------------------------------------------------
PGO_CMAKE_FILE="Build/pgohelper.cmake"
if [ -f "$PGO_CMAKE_FILE" ]; then
    echo "Applying custom PGO target parameters to $PGO_CMAKE_FILE..."
    run_sed 's/--preset[^)]*/--preset 2 --lookahead 120 --tune 0/g' "$PGO_CMAKE_FILE"
fi

# Platform Specific Configurations
OS_NAME=$(uname -s)
LLVM_PROFDATA_FLAG=""
CMAKE_CROSS_FLAGS=""
EXTRA_CFLAGS=""
EXTRA_LDFLAGS=""

if [ "$OS_NAME" = "Darwin" ]; then
    echo "Applying macOS Clang PGO configurations..."
    if [ -f "CMakeLists.txt" ]; then
        run_sed 's/PGO_DIR}/PGO_DIR} -mllvm -vp-counters-per-site=4096/g' CMakeLists.txt
    fi
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA_FLAG="-DLLVM_PROFDATA=$(command -v llvm-profdata)"
    else
        XCODE_PATH=$(xcode-select -p 2>/dev/null)
        if [ -n "$XCODE_PATH" ] && [ -x "$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata" ]; then
            LLVM_PROFDATA_FLAG="-DLLVM_PROFDATA=$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-profdata"
        fi
    fi
elif [ "$TARGET_OS" = "Windows" ]; then
    echo "Applying Windows MinGW Cross-Compile PGO configurations..."
    
    # 核心魔术 1：指定工具链，并设置 CMAKE_CROSSCOMPILING_EMULATOR 为 wine64
    CMAKE_CROSS_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SCRIPT_DIR/mingw64.cmake -DCMAKE_CROSSCOMPILING_EMULATOR=wine64"
    
    # 核心魔术 2：因为 SVT-AV1 的 RunPGO 内部是由 CMake 多线程自动调度的，
    # 我们没法像 x265 那样搞目录隔离，所以重新请出 -fprofile-update=atomic 防数据损坏。
    #EXTRA_CFLAGS="-fprofile-update=atomic"
    
    # 核心魔术 3：静态链接 C++ 库，防止 Wine 运行时找不到 MinGW 的 DLL。
    EXTRA_LDFLAGS="-static"
    
    export WINEDEBUG=-all
fi

# 7. Configure
# ------------------------------------------------------------------------------
mkdir -p build
cd build || exit 1

echo "Configuring CMake..."

cmake \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_APPS=ON \
    -DSVT_AV1_LTO=ON \
    -DSVT_AV1_PGO=ON \
    -DSVT_AV1_PGO_CUSTOM_VIDEOS="$PGO_SAMPLE_DIR" \
    -DCMAKE_C_FLAGS="$EXTRA_CFLAGS" \
    -DCMAKE_CXX_FLAGS="$EXTRA_CFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$EXTRA_LDFLAGS" \
    $CMAKE_CROSS_FLAGS \
    $LLVM_PROFDATA_FLAG \
    ..

checkStatus $? "CMake Configuration failed"

# 8. Execute PGO Training
# ------------------------------------------------------------------------------
echoSection "Running PGO Training (make RunPGO)"
echo "Compiling instrumented encoder -> Running training videos -> Compiling optimized encoder"

make RunPGO -j "$CPUS"
checkStatus $? "PGO Training failed"

# 9. Install
# ------------------------------------------------------------------------------
echoSection "Installing SVT-AV1"
make install
checkStatus $? "Installation failed"

# 10. Cleanup
# ------------------------------------------------------------------------------
echo "Cleaning up PGO temporary samples..."
rm -rf "$PGO_SAMPLE_DIR"

echoSection "SVT-AV1 Build Complete"