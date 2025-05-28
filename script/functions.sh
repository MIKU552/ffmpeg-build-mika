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

# --- Version Fetching Helper Functions ---

# Fetches the latest release tag name from a GitHub repository
# Arg1: GitHub repository in "owner/repo" format (e.g., "libass/libass")
get_latest_github_release_tag() {
    local repo_path="$1"
    if [ -z "$repo_path" ]; then
        echo "ERROR: GitHub repository path not provided to get_latest_github_release_tag."
        return 1
    fi
    local tag_name
    tag_name=$(curl -s "https://api.github.com/repos/${repo_path}/releases/latest" | jq -r '.tag_name')
    if [ -z "$tag_name" ] || [ "$tag_name" = "null" ]; then
        echo "ERROR: Could not fetch latest release tag for GitHub repo ${repo_path}."
        return 1
    fi
    echo "$tag_name"
    return 0
}

# Fetches the latest release tag name from a GitLab repository
# Arg1: GitLab domain and URL-encoded project ID (e.g., "gitlab.gnome.org/GNOME%2Flibxml2")
get_latest_gitlab_release_tag() {
    local project_path="$1"
    if [ -z "$project_path" ]; then
        echo "ERROR: GitLab project path not provided to get_latest_gitlab_release_tag."
        return 1
    fi
    local tag_name
    # Assumes the first release in the list is the latest
    tag_name=$(curl -s "https://${project_path}/releases" | jq -r '.[0].tag_name')
    if [ -z "$tag_name" ] || [ "$tag_name" = "null" ]; then
        echo "ERROR: Could not fetch latest release tag for GitLab project ${project_path}."
        return 1
    fi
    echo "$tag_name"
    return 0
}

# Fetches the latest version string from an HTML directory listing by parsing href links
# Arg1: URL of the directory listing page
# Arg2: A grep -oP compatible regex to extract the full href attribute of relevant tarballs.
#       This regex MUST include a capturing group around the version part of the filename.
#       Example: 'href="(libopus-([0-9\.]+)\.tar\.gz)"' - this captures "libopus-1.2.3.tar.gz" in group 1, and "1.2.3" in group 2.
# Arg3: A sed -E expression to isolate the version string from the output of grep (from group 1).
#       Example: 's|href="libopus-([0-9\.]+)\.tar\.gz"|\1|' (if Arg2 was just 'href="libopus-([0-9\.]+)\.tar\.gz"')
#       If Arg2 is more complex like 'href="(libopus-([0-9\.]+)\.tar\.gz)"', this sed might be 's|.*\libopus-([0-9\.]+)\.tar\.gz.*|\1|' to get version part.
#       Or more simply, if the grep pattern correctly isolates filenames: 's|libname-([0-9\.]+)\.tar\.(gz|xz|bz2)|\1|'
# Arg4: (Optional) A grep -E filter for valid version strings (e.g., '^[0-9]+\.[0-9]+(\.[0-9]+)*$')
get_latest_html_link_version() {
    local page_url="$1"
    local href_grep_pattern="$2" # e.g., 'href="libname-([0-9\.]+)\.tar\.gz"'
    local version_sed_expr="$3" # e.g., 's|libname-([0-9\.]+)\.tar\.gz|\1|'
    local version_filter_grep_pattern="${4:-"^[0-9]+\.[0-9]+(\.[0-9]+)*$"}" # Default filter

    if [ -z "$page_url" ] || [ -z "$href_grep_pattern" ] || [ -z "$version_sed_expr" ]; then
        echo "ERROR: Insufficient arguments for get_latest_html_link_version."
        return 1
    fi

    local latest_version
    latest_version=$(curl -sL "$page_url" | \
        grep -oP "$href_grep_pattern" | \
        sed -E "$version_sed_expr" | \
        grep -E "$version_filter_grep_pattern" | \
        sort -V | tail -n 1)

    if [ -z "$latest_version" ]; then
        echo "ERROR: Could not determine latest version from $page_url using pattern $href_grep_pattern."
        return 1
    fi
    echo "$latest_version"
    return 0
}

# Determines the tarball extension for a given base URL and version
# Arg1: Base download URL prefix (e.g., "https://downloads.xiph.org/releases/opus/opus-1.3.1")
#       (This should NOT include the .tar.ext part)
# Arg2: Default extension if none found (e.g., ".tar.gz")
determine_tarball_extension() {
    local base_url_prefix="$1"
    local default_ext="$2"
    local found_ext=""

    if curl -sL --head "${base_url_prefix}.tar.gz" | grep -q "200 OK"; then
        found_ext=".tar.gz"
    elif curl -sL --head "${base_url_prefix}.tar.xz" | grep -q "200 OK"; then
        found_ext=".tar.xz"
    elif curl -sL --head "${base_url_prefix}.tar.bz2" | grep -q "200 OK"; then
        found_ext=".tar.bz2"
    fi

    if [ -n "$found_ext" ]; then
        echo "$found_ext"
    else
        echo "$default_ext"
    fi
    return 0
}