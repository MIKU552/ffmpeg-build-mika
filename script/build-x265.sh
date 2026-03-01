#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
# Merged for Linux & macOS compatibility - Reverted Linux lib merging to original 'ar -M'
# [Modified] PGO steps entirely removed for faster and stabler builds.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4
SKIP_X265_MULTIBIT=$5

# load functions (including run_sed)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/functions.sh"

# --- OS Detection ---
OS_NAME=$(uname)

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir -p "x265"
cd "x265/"
checkStatus $? "change directory failed"

# download source
X265_TARBALL="x265-$VERSION.tar.gz"
X265_UNPACK_DIR="x265-src"
download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "$X265_TARBALL"
checkStatus $? "download of x265 failed"

# unpack
mkdir -p "$X265_UNPACK_DIR"
checkStatus $? "create directory failed"
tar -zxf "$X265_TARBALL" -C "$X265_UNPACK_DIR" --strip-components=1
checkStatus $? "unpack failed"
rm "$X265_TARBALL" # Clean up
cd "$X265_UNPACK_DIR/"
checkStatus $? "change directory failed"


# --- Apply CMake Patches ---
X265_MAIN_CMAKE_PATH="source/CMakeLists.txt"
echo "Patching $X265_MAIN_CMAKE_PATH..."
if [ -f "$X265_MAIN_CMAKE_PATH" ]; then
    run_sed '1a\
cmake_minimum_required(VERSION 3.10)
' "$X265_MAIN_CMAKE_PATH"

    run_sed 's/project *\(.*\)/project(x265 CXX C ASM)/' "$X265_MAIN_CMAKE_PATH"

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
    ' "$X265_MAIN_CMAKE_PATH" > "$X265_MAIN_CMAKE_PATH.tmp" && mv "$X265_MAIN_CMAKE_PATH.tmp" "$X265_MAIN_CMAKE_PATH"
    checkStatus $? "Adding includes to CMakeLists.txt failed"

    if [ "$OS_NAME" = "Darwin" ]; then
         run_sed '/cmake_minimum_required(VERSION 3.10)/a \
cmake_policy(SET CMP0069 NEW)
' "$X265_MAIN_CMAKE_PATH"
    fi
    echo "CMakeLists.txt patched."
else
    echo "ERROR: $X265_MAIN_CMAKE_PATH not found! Cannot patch."
    exit 1
fi
# --- End CMake Patches ---

# --- OS Specific Flags ---
NASM_FLAGS=""
if [ "$OS_NAME" = "Linux" ]; then
    NASM_FLAGS="-DENABLE_CET=0" # Keep CET disable for Linux/GCC NASM
fi

# --- Standard Build (No PGO) ---
if [ "$SKIP_X265_MULTIBIT" = "NO" ]; then
    # --- Multi-bit Build ---
    echo "Starting multi-bit build (No PGO)..."
    mkdir -p 10bit 12bit
    checkStatus $? "create 10/12bit directories failed"

    echo "Configuring/Building 10bit..."
    cd 10bit/
    checkStatus $? "cd 10bit failed"
    # shellcheck disable=SC2086
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF \
          -DHIGH_BIT_DEPTH=ON \
          ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
          ../source
    checkStatus $? "configuration 10 bit failed"
    make -j $CPUS
    checkStatus $? "build 10 bit failed"
    cd ..
    checkStatus $? "cd .. from 10bit failed"

    echo "Configuring/Building 12bit..."
    cd 12bit/
    checkStatus $? "cd 12bit failed"
    # shellcheck disable=SC2086
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF \
          -DHIGH_BIT_DEPTH=ON -DMAIN12=ON \
          ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
          ../source
    checkStatus $? "configuration 12 bit failed"
    make -j $CPUS
    checkStatus $? "build 12 bit failed"
    cd ..
    checkStatus $? "cd .. from 12bit failed"

    echo "Configuring/Building 8bit (linking 10/12bit)..."
    ln -sf 10bit/libx265.a libx265_10bit.a
    checkStatus $? "symlink creation of 10 bit library failed"
    ln -sf 12bit/libx265.a libx265_12bit.a
    checkStatus $? "symlink creation of 12 bit library failed"
    # shellcheck disable=SC2086
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
          -DEXTRA_LINK_FLAGS=-L. \
          -DEXTRA_LIB="x265_10bit.a;x265_12bit.a" \
          -DLINKED_10BIT=ON -DLINKED_12BIT=ON \
          ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
          source
    checkStatus $? "configuration 8 bit failed"
    make -j $CPUS
    checkStatus $? "build 8 bit failed"

    # --- Merge libraries ---
    echo "Merging libraries..."
    mv libx265.a libx265_8bit.a
    checkStatus $? "move 8 bit library failed"
    if [ "$OS_NAME" = "Linux" ]; then
        ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_8bit.a
ADDLIB libx265_10bit.a
ADDLIB libx265_12bit.a
SAVE
END
EOF
        checkStatus $? "ar -M multi-bit library creation failed"
    elif [ "$OS_NAME" = "Darwin" ]; then
        libtool -static -o libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
        checkStatus $? "libtool multi-bit library creation failed"
    fi

else
    # --- Single Build (8-bit only) ---
    echo "Starting single-bit (8bit) build (No PGO)..."
    # shellcheck disable=SC2086
    cmake -DCMAKE_INSTALL_PREFIX:PATH="$TOOL_DIR" \
          -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
          -DENABLE_SHARED=NO \
          -DENABLE_CLI=OFF \
          ${NASM_FLAGS:+-DCMAKE_ASM_NASM_FLAGS="$NASM_FLAGS"} \
          source
    checkStatus $? "configuration single-bit failed"
    make -j $CPUS
    checkStatus $? "build single-bit failed"
fi

# --- Install ---
echo "Installing x265..."
make install
checkStatus $? "installation failed"

# --- Post-installation pkg-config fix ---
echo "Applying post-installation fix to x265.pc..."
PKGCONFIG_PATH_LIB="$TOOL_DIR/lib/pkgconfig/x265.pc"
PKGCONFIG_PATH_LIB64="$TOOL_DIR/lib64/pkgconfig/x265.pc"
ACTUAL_PC_FILE=""
if [ -f "$PKGCONFIG_PATH_LIB" ]; then ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB"; fi
if [ "$OS_NAME" = "Linux" ] && [ -f "$PKGCONFIG_PATH_LIB64" ]; then ACTUAL_PC_FILE="$PKGCONFIG_PATH_LIB64"; fi

if [ -z "$ACTUAL_PC_FILE" ]; then
    echo "Warning: x265.pc not found!"
else
     echo "Found pkgconfig file at: $ACTUAL_PC_FILE"
     if ! grep -q -- "-lpthread" "$ACTUAL_PC_FILE"; then
         echo "Adding -lpthread to $ACTUAL_PC_FILE"
         if grep -q "^Libs.private:" "$ACTUAL_PC_FILE"; then run_sed "s|^Libs.private:.*|& -lpthread|" "$ACTUAL_PC_FILE";
         else run_sed "s|^Libs:.*|& -lpthread|" "$ACTUAL_PC_FILE"; fi
         checkStatus $? "modify pkgconfig file failed"
     else echo "-lpthread already seems present."; fi
fi

cd ../.. # Back to SOURCE_DIR/x265