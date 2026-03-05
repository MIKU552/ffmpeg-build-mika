#!/bin/bash

# ==============================================================================
# Build Script for rav1e (Fastest/Safest AV1 Encoder)
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

echoSection "Building rav1e"

# 2. Pre-flight Checks (Fail Fast)
# As per README, Rust and cargo-c are prerequisites.
if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: 'cargo' not found in PATH."
    echo "Please install Rust (https://rustup.rs/) before running this script."
    exit 1
fi

if ! command -v cargo-cinstall >/dev/null 2>&1; then
    echo "Error: 'cargo-cinstall' command not found."
    echo "Please install it manually: cargo install cargo-c"
    exit 1
fi

# 3. Version & Directory Setup
VERSION_FILE="$SCRIPT_DIR/../version/rav1e"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "Error: Version file not found."
    exit 1
fi

echo "Target Version: $VERSION"

# Prepare Source Directory
TARGET_SRC_DIR="$SOURCE_DIR/rav1e"
mkdir -p "$TARGET_SRC_DIR"
cd "$TARGET_SRC_DIR" || exit 1

# 4. Download Source
# URL: https://github.com/xiph/rav1e/archive/refs/tags/v0.6.6.tar.gz
TARBALL="rav1e-$VERSION.tar.gz"
URL="https://github.com/xiph/rav1e/archive/refs/tags/v$VERSION.tar.gz"

download "$URL" "$TARBALL"

# Unpack
SRC_DIR_NAME="rav1e-src"
mkdir -p "$SRC_DIR_NAME"
tar -zxf "$TARBALL" -C "$SRC_DIR_NAME" --strip-components=1
checkStatus $? "Unpack failed"
rm "$TARBALL"

# 5. Build & Install
cd "$SRC_DIR_NAME" || exit 1

echo "Compiling rav1e (release mode)..."

# Command breakdown:
# cargo cinstall: The C-API installer command
# --release: Optimize for performance
# --library-type=staticlib: Build static library (.a) for FFmpeg linking
# --frozen: Require Cargo.lock and cache are up to date (optional, but good for reproducibility)
# --prefix/--libdir/etc: Explicit install paths to avoid system pollution
cargo cinstall \
    --release \
    --library-type=staticlib \
    --prefix="$TOOL_DIR" \
    --libdir="$TOOL_DIR/lib" \
    --includedir="$TOOL_DIR/include" \
    --pkgconfigdir="$TOOL_DIR/lib/pkgconfig" \
    --jobs "$CPUS"

checkStatus $? "Build or Installation failed"

echoSection "rav1e Build Complete"