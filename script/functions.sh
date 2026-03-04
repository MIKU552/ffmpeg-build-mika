#!/bin/bash

# ==============================================================================
# FFmpeg Build Script - Helper Functions
# ==============================================================================
# Refactored and Optimized
#
# Description:
#   Contains shared utility functions for logging, timing, downloading,
#   environment setup (Meson/Python), and OS-specific fixups (dylib relocation).
#
# License: Apache License, Version 2.0
# ==============================================================================

# --- OS Detection ---
OS_NAME=$(uname -s)

# --- Colors for Logging ---
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# ------------------------------------------------------------------------------
# Logging & Status Checks
# ------------------------------------------------------------------------------

# Docstring: checkStatus
# Checks the exit code of the previous command. Exits script on failure.
# Usage: checkStatus $? "Error message"
checkStatus(){
    local status=$1
    local message=$2
    if [ $status -ne 0 ]; then
        echo -e "${RED}ERROR: ${message} (Exit Code: ${status})${NC}"
        exit 1
    fi
}

# Docstring: echoSection
# Prints a formatted section header.
# Usage: echoSection "Building x264"
echoSection(){
    echo ""
    echo -e "${GREEN}=== $1 ===${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Timing Functions
# ------------------------------------------------------------------------------

currentTimeInSeconds(){
    date +%s
}

echoDurationInSections(){
    local start_time=$1
    local end_time=$(currentTimeInSeconds)
    
    if [[ "$start_time" =~ ^[0-9]+$ ]] && [[ "$end_time" =~ ^[0-9]+$ ]]; then
        local duration=$((end_time - start_time))
        # Prevent negative duration due to clock skew
        if [ "$duration" -lt 0 ]; then duration=0; fi
        
        # Format as MM:SS if longer than 60s, else just seconds
        if [ "$duration" -gt 60 ]; then
            local min=$((duration / 60))
            local sec=$((duration % 60))
            echo -e "${YELLOW}Duration: ${min}m ${sec}s${NC}"
        else
            echo -e "${YELLOW}Duration: ${duration}s${NC}"
        fi
    else
        echo "Duration: Unknown (Invalid start time)"
    fi
}

# ------------------------------------------------------------------------------
# Network & Download
# ------------------------------------------------------------------------------

# Docstring: download
# Downloads a file using curl with retry logic.
# Usage: download "http://example.com/file.tar.gz" "output.tar.gz"
download(){
    local url=$1
    local output_name=$2
    
    echo "Downloading: $url -> $output_name"
    # -L: Follow redirects
    # -f: Fail silently on server errors (404/500) so we can catch exit code
    # --retry 3: Retry up to 3 times on transient errors
    # --connect-timeout 10: Timeout for connection
    curl -L -f --retry 3 --connect-timeout 10 -o "$output_name" "$url"
    
    checkStatus $? "Failed to download $url"
}

# ------------------------------------------------------------------------------
# Build Environment Helpers (Meson/Python)
# ------------------------------------------------------------------------------

# Docstring: prepareMeson
# Sets up Meson build system. Prefers system meson, falls back to local venv.
prepareMeson(){
    echo "Checking for Meson build system..."

    # 1. Try System Meson first
    if command -v meson >/dev/null 2>&1; then
        local version
        version=$(meson -v)
        echo "Found system Meson: $version"
        return 0
    fi

    echo "System Meson not found. Attempting to create Python virtual environment..."

    # 2. Check Python Prerequisites
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}ERROR: python3 is required for Meson but not found.${NC}"
        exit 1
    fi

    # 3. Create/Activate Virtual Environment
    local venv_dir=".venv"
    
    # Only create if it doesn't exist to save time
    if [ ! -d "$venv_dir" ]; then
        python3 -m venv "$venv_dir"
        checkStatus $? "Failed to create python virtual environment"
    fi

    # Activate
    if [ -f "$venv_dir/bin/activate" ]; then
        # shellcheck source=/dev/null
        . "$venv_dir/bin/activate"
    else
        echo -e "${RED}ERROR: Virtual environment created but activate script missing.${NC}"
        exit 1
    fi

    # 4. Install Meson & Ninja via pip
    # Check if already installed in venv to save time
    if ! command -v meson >/dev/null 2>&1; then
        echo "Installing Meson and Ninja via pip..."
        pip install meson ninja
        checkStatus $? "Failed to pip install meson ninja"
    fi

    echo "Meson setup complete (via venv): $(meson -v)"
}

# ------------------------------------------------------------------------------
# File Manipulation (sed)
# ------------------------------------------------------------------------------

# Docstring: run_sed
# Cross-platform wrapper for sed -i (in-place edit).
# Usage: run_sed "s/foo/bar/g" "file.txt"
run_sed() {
    local expression=$1
    local file=$2
    
    if [ ! -f "$file" ]; then
        echo "Warning: run_sed called on non-existent file: $file"
        return 1
    fi

    # echo "Patching $file..."
    if [ "$OS_NAME" = "Darwin" ]; then
        # macOS sed requires an empty string for extension backup
        sed -i '' "$expression" "$file"
    else
        # GNU sed
        sed -i "$expression" "$file"
    fi
    checkStatus $? "sed patch failed on $file"
}

# ------------------------------------------------------------------------------
# macOS Specific: Dynamic Library Relocation
# ------------------------------------------------------------------------------

if [ "$OS_NAME" = "Darwin" ]; then

    # Docstring: relocateDylib
    # Fixes the install name of dylibs in the output directory so they are relative
    # to the executable (@executable_path), making the build portable.
    relocateDylib(){
        echoSection "Relocating macOS Dynamic Libraries"

        if [ -z "$OUT_DIR" ] || [ ! -d "$OUT_DIR/bin" ]; then
            echo -e "${RED}ERROR: OUT_DIR not set or bin/ missing.${NC}"
            return 1
        fi

        local EXES=("ffmpeg" "ffplay" "ffprobe")
        
        for exe_name in "${EXES[@]}"; do
            local bin_path="$OUT_DIR/bin/$exe_name"
            
            if [ ! -f "$bin_path" ]; then
                echo "Skipping $exe_name (not found)"
                continue
            fi
            
            echo "Processing executable: $exe_name"
            
            # Get list of linked libraries that are inside our build lib folder
            # We filter for the specific build path to avoid touching system libs
            local libs_to_fix
            libs_to_fix=$(otool -L "$bin_path" | grep "$OUT_DIR/lib/" | awk '{print $1}')
            
            for full_lib_path in $libs_to_fix; do
                local lib_filename
                lib_filename=$(basename "$full_lib_path")
                local target_path="@executable_path/../lib/$lib_filename"
                
                # echo "  -> Remapping $lib_filename"
                
                install_name_tool -change "$full_lib_path" "$target_path" "$bin_path"
                if [ $? -ne 0 ]; then
                    echo -e "${YELLOW}WARNING: install_name_tool failed for $lib_filename in $exe_name${NC}"
                fi
            done
            
            # Optional: Codesign (adhoc) to prevent "unidentified developer" warnings locally
            # codesign -s - "$bin_path" 2>/dev/null
        done
        
        echo "Relocation complete."
    }

fi