#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
# Merged for Linux & macOS compatibility

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# --- OS Detection ---
OS_NAME=$(uname)

checkStatus(){
    if [ $1 -ne 0 ]
    then
        echo "check failed: $2"
        exit 1
    fi
}

echoSection(){
    echo ""
    echo "$1"
}

currentTimeInSeconds(){
    # `date +%s` is POSIX standard
    local TIME_GDATE=$(date +%s)
    if [ $? -eq 0 ]
    then
        echo $TIME_GDATE
    else
        echo 0
    fi
}

echoDurationInSections(){
    local END_TIME=$(currentTimeInSeconds)
    # Check if START_TIME ($1) is numeric
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$END_TIME" =~ ^[0-9]+$ ]]; then
         local DURATION=$((END_TIME - $1))
         # Handle potential clock skew or very fast operations resulting in negative/zero duration
         if [ "$DURATION" -lt 0 ]; then
             DURATION=0
         fi
         echo "took ${DURATION}s"
    else
        echo "took unknown time (invalid start time: $1)"
    fi
}


download(){
    local URL=$1
    local NAME=$2
    # Use curl options common to both platforms
    curl -o "$NAME" -L -f "$URL"
}

prepareMeson(){
    # Check if python3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is required for meson builds but not found."
        exit 1
    fi
    # Check if pip is available
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "ERROR: python3-pip is required for meson builds but not found."
        exit 1
    fi
     # Check if venv module is available
    if ! python3 -m venv --help >/dev/null 2>&1; then
        echo "ERROR: python3 venv module (often python3-venv package) is required for meson builds but not found."
        exit 1
    fi


    python3 -m venv .venv
    if [ $? -ne 0 ]; then
        echo "python create virtual environment failed"

        # check, if meson is natively available
        if command -v meson >/dev/null 2>&1; then
             MESON_VERSION=$(meson -v 2> /dev/null)
             checkStatus $? "meson native check failed"
             echo "using native meson $MESON_VERSION"
        else
            echo "Meson was not found natively and virtualenv creation failed."
            echo "Please ensure python3, python3-pip, and python3-venv are installed correctly."
            exit 1
        fi
    else
        echo "Activating python virtual environment..."
        # Source activation script based on shell (common pattern)
        if [ -f ".venv/bin/activate" ]; then
            # shellcheck source=/dev/null
            . .venv/bin/activate
            checkStatus $? "python activate virtual environment failed"
            echo "Installing meson via pip..."
            pip install meson ninja # Install ninja here too if needed by meson build
            checkStatus $? "python meson/ninja installation failed"
            # Display version after install
            meson -v
        else
            echo "ERROR: virtual environment created, but activate script not found at .venv/bin/activate"
            exit 1
        fi
    fi
}

# --- macOS Specific Functions ---
if [ "$OS_NAME" = "Darwin" ]; then
    relocateDylib(){
        echo "Relocating dylibs for macOS..."
        # Ensure OUT_DIR is available (passed from build.sh context)
        if [ -z "$OUT_DIR" ] || [ ! -d "$OUT_DIR/bin" ] || [ ! -d "$OUT_DIR/lib" ]; then
             echo "ERROR: OUT_DIR variable not set or directories missing for relocateDylib."
             return 1 # Use return instead of exit in function if called from main script
        fi

        local EXES=("ffmpeg" "ffplay" "ffprobe")
        for exe in "${EXES[@]}"; do
            local BIN="$OUT_DIR/bin/$exe"
            if [ ! -f "$BIN" ]; then
                echo "Warning: Executable not found for relocation: $BIN"
                continue
            fi
            echo "Processing $exe..."
            # Use otool to find dependencies pointing inside OUT_DIR/lib
            otool -L "$BIN" | grep "$OUT_DIR/lib/" | awk '{print $1}' | while read -r dep; do
                if [ -z "$dep" ]; then continue; fi # Skip empty lines
                local libname
                libname=$(basename "$dep")
                # Check if the actual library file exists before trying to change
                if [ -e "$OUT_DIR/lib/$libname" ]; then
                    echo "  Changing path for $libname in $exe: $dep -> @executable_path/../lib/$libname"
                    install_name_tool -change \
                        "$dep" \
                        "@executable_path/../lib/$libname" \
                        "$BIN"
                    # Check status but maybe don't exit immediately? Log error?
                    local change_status=$?
                    if [ $change_status -ne 0 ]; then
                        echo "ERROR: install_name_tool failed for $libname in $exe (Exit code: $change_status)"
                        # Decide whether to continue or exit based on severity
                        # return 1 # Optionally stop on first error
                    fi
                else
                    echo "Warning: Dependency target $OUT_DIR/lib/$libname not found, skipping change for $dep in $exe."
                fi
            done
            checkStatus $? "otool/awk processing failed for $exe"
        done
         echo "Dylib relocation finished."
    }
fi # End macOS Specific Functions

# --- Helper for sed ---
run_sed() {
    local expression=$1
    local file=$2
    echo "Running sed expression '$expression' on '$file'"
    if [ "$OS_NAME" = "Darwin" ]; then
        sed -i '' "$expression" "$file"
    else # Linux
        sed -i "$expression" "$file"
    fi
    checkStatus $? "sed command failed on $file with expression '$expression'"
}