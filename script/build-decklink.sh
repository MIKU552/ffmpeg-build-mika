#!/bin/bash

# ==============================================================================
# Build Script for Blackmagic DeckLink SDK
# ==============================================================================
# Part of FFmpeg Build Script
# Licensed under Apache License, Version 2.0
# ==============================================================================

# 1. Argument Processing
# Note: Arguments must match the standard signature called by run_build in build_fix.sh
echo "Arguments: $@"
SCRIPT_DIR="$1"
SOURCE_DIR="$2" # Unused for Decklink (external SDK)
TOOL_DIR="$3"
CPUS="$4"       # Unused
DECKLINK_SDK="$5"

# Load Helper Functions
if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    . "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found."
    exit 1
fi

echoSection "Installing DeckLink SDK Headers"

# 2. Validate SDK Path
if [ -z "$DECKLINK_SDK" ]; then
    echo "Error: DECKLINK_SDK path is empty. Please pass it via -DECKLINK_SDK=..."
    exit 1
fi

echo "SDK Path: $DECKLINK_SDK"

# 3. Check for Header File
# FFmpeg requires DeckLinkAPI.h to enable --enable-decklink
HEADER_FILE="$DECKLINK_SDK/DeckLinkAPI.h"

if [ ! -f "$HEADER_FILE" ]; then
    echo "Error: DeckLinkAPI.h not found in $DECKLINK_SDK"
    echo "Please ensure the path points directly to the directory containing the header files (usually 'include' folder in the SDK)."
    exit 1
fi

# 4. Install Headers
# We only need to copy the headers to the toolchain include directory.
# FFmpeg will look for them there.
echo "Copying headers to $TOOL_DIR/include..."

mkdir -p "$TOOL_DIR/include"

# Copy all headers and IDL files
cp "$DECKLINK_SDK"/*.h "$TOOL_DIR/include/" 2>/dev/null
cp "$DECKLINK_SDK"/*.idl "$TOOL_DIR/include/" 2>/dev/null

# Verify copy
if [ -f "$TOOL_DIR/include/DeckLinkAPI.h" ]; then
    echo "DeckLink SDK installed successfully."
else
    checkStatus 1 "Failed to copy DeckLink headers."
fi