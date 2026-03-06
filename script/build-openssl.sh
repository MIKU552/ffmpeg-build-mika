#!/bin/bash

# ==============================================================================
# Build Script for OpenSSL (Cryptography and SSL/TLS)
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
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

echoSection "Building OpenSSL"

# 2. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/openssl"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/openssl"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 3. Download Source
# URL: https://github.com/openssl/openssl/releases/download/openssl-3.1.2/openssl-3.1.2.tar.gz
TARBALL="openssl-$VERSION.tar.gz"
URL="https://github.com/openssl/openssl/releases/download/openssl-$VERSION/openssl-$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="openssl-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 4. Configure
cd "$SRC_DIR_NAME" || exit 1

echo "Configuring OpenSSL..."

# ==============================================================================
# OpenSSL Cross-Compilation Override
# OpenSSL uses a custom Perl Configure script. If we don't explicitly tell it 
# we are targeting Windows, it will guess Linux, causing LP64 vs LLP64 crashes.
# ==============================================================================
CONFIG_CMD="./config"
CROSS_FLAGS=""

if [ "$TARGET_OS" = "Windows" ]; then
    # 不用 config 瞎猜，直接用 Configure 强行指定 mingw64 目标
    CONFIG_CMD="./Configure"
    CROSS_FLAGS="mingw64"
fi

# 执行配置 (保留你原有的其他参数，比如 no-shared 等)
$CONFIG_CMD \
    $CROSS_FLAGS \
    --prefix="$TOOL_DIR" \
    --libdir=lib \
    no-shared \
    no-dso \
    no-quic \
    no-tests

checkStatus $? "Configuration failed"

# 5. Build
echo "Compiling..."
make -j "$CPUS"
checkStatus $? "Build failed"

# 6. Install
echo "Installing..."

# install_sw: Install Software (headers, libs, bins) but NOT docs.
# install_ssldirs: Create the certs/private directory structure.
make install_sw
checkStatus $? "Installation (software) failed"

make install_ssldirs
checkStatus $? "Installation (ssl dirs) failed"

echoSection "OpenSSL Build Complete"