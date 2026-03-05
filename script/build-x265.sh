#!/bin/bash

# ==============================================================================
# Build Script for x265 (H.265/HEVC Video Encoder)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
#
# Features:
#   - Multi-bit depth support (8bit + 10bit + 12bit)
#   - Profile-Guided Optimization (PGO) tailored to custom encoding parameters
#   - Cross-platform Static Linking (ar script for Linux, libtool for macOS)
# ==============================================================================

# 1. Argument Processing
echo "Arguments: $@"
SCRIPT_DIR="$1"
SOURCE_DIR="$2"
TOOL_DIR="$3"
CPUS="$4"
SKIP_X265_MULTIBIT="$5"

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

# --- OS Detection ---
OS_NAME=$(uname -s)

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/x265"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found at $VERSION_FILE"
    exit 1
fi

echoSection "Building x265 (Version: $VERSION)"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/x265"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download & Unpack
X265_TARBALL="x265-$VERSION.tar.gz"
URL="https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz"

download "$URL" "$X265_TARBALL"

SRC_DIR_NAME="x265-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$X265_TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$X265_TARBALL"
cd "$SRC_DIR_NAME" || exit 1

# 4. Patch CMakeLists.txt
CMAKE_FILE="source/CMakeLists.txt"
echo "Patching $CMAKE_FILE..."

if [ -f "$CMAKE_FILE" ]; then
    run_sed '1a\
cmake_minimum_required(VERSION 3.10)
' "$CMAKE_FILE"

    run_sed 's/project *\(.*\)/project(x265 CXX C ASM)/' "$CMAKE_FILE"

    awk '
    /project *\(.*\)/ {
        print;
        print "include(CheckIncludeFiles)";
        print "include(CheckSymbolExists)";
        print "include(CheckCCompilerFlag)";
        print "include(CheckCXXCompilerFlag)";
        next
    }
    { print }
    ' "$CMAKE_FILE" > "${CMAKE_FILE}.tmp" && mv "${CMAKE_FILE}.tmp" "$CMAKE_FILE"
    checkStatus $? "Failed to patch includes in CMakeLists.txt"

    if [ "$OS_NAME" = "Darwin" ]; then
        run_sed '/cmake_minimum_required(VERSION 3.10)/a \
cmake_policy(SET CMP0069 NEW)
' "$CMAKE_FILE"
    fi
else
    echo "ERROR: $CMAKE_FILE not found."
    exit 1
fi

# 5. Define PGO Flags
# ------------------------------------------------------------------------------
PGO_GEN_CFLAGS=""
PGO_GEN_CXXFLAGS=""
PGO_USE_CFLAGS=""
PGO_USE_CXXFLAGS=""
NASM_FLAGS=""
LLVM_PROFDATA_CMD=""

if [ "$OS_NAME" = "Darwin" ]; then
    PGO_GEN_CFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    PGO_GEN_CXXFLAGS="-fprofile-generate -mllvm -vp-counters-per-site=2048"
    
    if command -v llvm-profdata >/dev/null 2>&1; then
        LLVM_PROFDATA_CMD=$(command -v llvm-profdata)
    else
        XCODE_TOOLCHAIN="$(xcode-select -p 2>/dev/null)/Toolchains/XcodeDefault.xctoolchain/usr/bin"
        if [ -x "$XCODE_TOOLCHAIN/llvm-profdata" ]; then
            LLVM_PROFDATA_CMD="$XCODE_TOOLCHAIN/llvm-profdata"
        else
            echo "Warning: llvm-profdata not found. PGO might fail on macOS."
        fi
    fi
else
    PGO_GEN_CFLAGS="-fprofile-generate"
    PGO_GEN_CXXFLAGS="-fprofile-generate"
    # Added -Wno-coverage-mismatch to ignore branching changes caused by LINKED_10BIT macros
    # Added -Wno-alloc-size-larger-than to suppress GCC 13+ false positives during PGO inlining
    PGO_USE_CFLAGS="-fprofile-use -Wno-missing-profile -Wno-coverage-mismatch -Wno-error=coverage-mismatch -Wno-alloc-size-larger-than"
    PGO_USE_CXXFLAGS="-fprofile-use -Wno-missing-profile -Wno-coverage-mismatch -Wno-error=coverage-mismatch -Wno-alloc-size-larger-than"
    NASM_FLAGS="-DENABLE_CET=0"
fi

# 6. PGO Step 1: Build Generators
# ------------------------------------------------------------------------------
echoSection "PGO Step 1: Building Generators"

build_generator() {
    local bit_depth=$1
    local extra_cmake_flags=$2
    local build_dir="${bit_depth}bitgen"

    echo "Building $bit_depth-bit PGO generator..."
    mkdir -p "$build_dir"
    cd "$build_dir" || exit 1
    
    # shellcheck disable=SC2086
    cmake -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO \
          $extra_cmake_flags \
          -DCMAKE_C_FLAGS="$PGO_GEN_CFLAGS" \
          -DCMAKE_CXX_FLAGS="$PGO_GEN_CXXFLAGS" \
          ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
          ../source
          
    checkStatus $? "$bit_depth-bit generator config failed"
    make -j "$CPUS"
    checkStatus $? "$bit_depth-bit generator build failed"
    cd ..
}

build_generator "8" ""
if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    build_generator "10" "-DHIGH_BIT_DEPTH=ON"
    build_generator "12" "-DHIGH_BIT_DEPTH=ON -DMAIN12=ON"
fi

# 7. PGO Step 2: Training
# ------------------------------------------------------------------------------
echoSection "PGO Step 2: Training (Custom Video Encoding)"

train_generator() {
    local bit_depth=$1
    local dir="${bit_depth}bitgen"
    local sample_dir="$SCRIPT_DIR/../sample"
    local samples=("stefan_sif.y4m.xz" "taikotemoto.y4m.xz" "720p_bbb.y4m.xz" "4k_bbb.y4m.xz")
    
    echo "Training $bit_depth-bit in $dir..."
    
    local current_dir=$(pwd)
    cd "$dir" || return
    
    for sample in "${samples[@]}"; do
        if [ -f "$sample_dir/$sample" ]; then
            echo "Running x265 training on $sample ($bit_depth-bit)..."
            
            # NOTE: We must use strictly valid x265 CLI arguments here.
            # Removed: --gop-lookahead (not a valid standalone CLI arg)
            # Removed: =1 suffixes for boolean flags (use --flag instead)
            # Removed: > /dev/null 2>&1 so we can actually see errors if it crashes!
            
            xz -dc "$sample_dir/$sample" | ./x265 \
                --y4m \
                --input - \
                --output /dev/null \
                --frames 50 \
                --preset veryslow \
                --crf 28 \
                --no-info \
                --rc-lookahead 250 \
                --open-gop
                
            # If x265 crashes, fail loudly
            if [ ${PIPESTATUS[1]} -ne 0 ]; then
                echo "ERROR: x265 training crashed on $sample!"
                exit 1
            fi
        else
            echo "Warning: Sample $sample not found in $sample_dir. Skipping."
        fi
    done
    echo "$bit_depth-bit training done."
    
    cd "$current_dir" || return
}

# Run training sequentially
train_generator "8"

if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    train_generator "10"
    train_generator "12"
fi

# We don't need 'wait' anymore since we removed the '&' background jobs.
checkStatus $? "PGO Training failed"

# 8. PGO Step 3: Process Profiles
# ------------------------------------------------------------------------------
echoSection "PGO Step 3: Merging Profiles"

if [ "$OS_NAME" = "Darwin" ]; then
    if [ -n "$LLVM_PROFDATA_CMD" ]; then
        echo "Merging profraw files..."
        $LLVM_PROFDATA_CMD merge -o default.profdata */*.profraw
        checkStatus $? "llvm-profdata merge failed"
        
        ABS_PROF_PATH="$(pwd)/default.profdata"
        PGO_USE_CFLAGS="-fprofile-use=${ABS_PROF_PATH}"
        PGO_USE_CXXFLAGS="-fprofile-use=${ABS_PROF_PATH}"
        
        rm -f */*.profraw
    else
        echo "ERROR: llvm-profdata missing, cannot complete PGO build."
        exit 1
    fi
else
    echo "Linux GCC uses .gcda files in-place. No merge needed."
fi

# Do NOT delete 8bitgen etc. on Linux, GCC needs the .gcda files located there.
# If we delete them, -fprofile-use has no data to read.
if [ "$OS_NAME" = "Darwin" ]; then
    rm -rf 8bitgen 10bitgen 12bitgen
fi

# 9. Final Compilation
# ------------------------------------------------------------------------------
echoSection "Final Build"

build_final() {
    local bit_depth=$1
    local dir="${bit_depth}bit"
    local extra_flags=$2
    
    echo "Building Final $bit_depth-bit..."
    
    # For Linux GCC PGO, we must build in the exact same directory where training happened
    # to find the .gcda files properly. For macOS Clang, we can create a new dir.
    if [ "$OS_NAME" = "Linux" ]; then
        dir="${bit_depth}bitgen"
        cd "$dir" || exit 1
        make clean
        # Re-run cmake with USE flags in the existing dir
        cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
              -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
              -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
              $extra_flags \
              -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
              -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
              ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
              ../source
    else
        mkdir -p "$dir"
        cd "$dir" || exit 1
        cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
              -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
              -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
              $extra_flags \
              -DCMAKE_C_FLAGS="$PGO_USE_CFLAGS" \
              -DCMAKE_CXX_FLAGS="$PGO_USE_CXXFLAGS" \
              ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
              ../source
    fi
          
    checkStatus $? "$bit_depth-bit final config failed"
    make -j "$CPUS"
    checkStatus $? "$bit_depth-bit final build failed"
    cd ..
}

if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    build_final "10" "-DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF"
    build_final "12" "-DHIGH_BIT_DEPTH=ON -DMAIN12=ON -DEXPORT_C_API=OFF"
    
    # Determine directory names based on OS logic above
    LDIR="bit"
    if [ "$OS_NAME" = "Linux" ]; then LDIR="bitgen"; fi

    ln -sf 10${LDIR}/libx265.a libx265_10bit.a
    ln -sf 12${LDIR}/libx265.a libx265_12bit.a
    
    echo "Building Final 8-bit (with 10/12bit linked)..."
    build_final "8" "-DEXTRA_LINK_FLAGS=-L. -DEXTRA_LIB=x265_10bit.a;x265_12bit.a -DLINKED_10BIT=ON -DLINKED_12BIT=ON"
    
    echo "Merging static libraries..."
    mv 8${LDIR}/libx265.a libx265_8bit.a
    
    if [ "$OS_NAME" = "Linux" ]; then
        echo "Using GNU 'ar' script for merging..."
        ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_8bit.a
ADDLIB libx265_10bit.a
ADDLIB libx265_12bit.a
SAVE
END
EOF
        checkStatus $? "Library merge (ar) failed"
    elif [ "$OS_NAME" = "Darwin" ]; then
        echo "Using macOS libtool for merging..."
        libtool -static -o libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
        checkStatus $? "Library merge (libtool) failed"
    fi
    
    mv libx265.a 8${LDIR}/libx265.a
    cd 8${LDIR} || exit 1
else
    build_final "8" ""
    if [ "$OS_NAME" = "Linux" ]; then
        cd 8bitgen || exit 1
    else
        cd 8bit || exit 1
    fi
fi

# 10. Install
echo "Installing to $TOOL_DIR..."
make install
checkStatus $? "Installation failed"
cd .. # Back to x265-src

# 11. Post-Install Fix (x265.pc)
# ------------------------------------------------------------------------------
echoSection "Post-Install Fixes"

PC_FILE=""
if [ -f "$TOOL_DIR/lib/pkgconfig/x265.pc" ]; then
    PC_FILE="$TOOL_DIR/lib/pkgconfig/x265.pc"
elif [ -f "$TOOL_DIR/lib64/pkgconfig/x265.pc" ]; then
    PC_FILE="$TOOL_DIR/lib64/pkgconfig/x265.pc"
fi

if [ -n "$PC_FILE" ]; then
    echo "Patching $PC_FILE for static linking..."
    if ! grep -q -- "-lpthread" "$PC_FILE"; then
        if grep -q "^Libs.private:" "$PC_FILE"; then
            run_sed "s|^Libs.private:.*|& -lpthread|" "$PC_FILE"
        else
            run_sed "s|^Libs:.*|& -lpthread|" "$PC_FILE"
        fi
        echo "Added -lpthread to x265.pc"
    fi
else
    echo "Warning: x265.pc not found. FFmpeg configure might fail to detect x265."
fi

echoSection "x265 Build Complete"