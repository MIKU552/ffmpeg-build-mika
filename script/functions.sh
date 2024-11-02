#!/bin/sh

# Copyright 2021 Martin Riedl
# Copyright 2024 Hayden Zheng
#
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
    echo "took $(($END_TIME - $1))s"
}

download(){
    local URL=$1
    local NAME=$2
    curl -o "$NAME" -L -f "$URL"
}

prepareMeson(){
    python3 -m virtualenv .venv
    if [ $? -ne 0 ]; then
        echo "python create virtual environment failed"

        # check, if meson is natively available
        MESON_VERSION=$(meson -v 2> /dev/null)
        checkStatus $? "meson was also not found: please install python correctly with virtualenv"
        echo "using meson $MESON_VERSION"
    else
        . .venv/bin/activate
        checkStatus $? "python activate virtual environment failed"
        pip install meson
        checkStatus $? "python meson installation failed"
    fi
}

relocateDylib(){
    local EXES=("ffmpeg" "ffplay" "ffprobe")
    local DYLIBS=()

    cd $OUT_DIR/lib
    for file in lib*.*.dylib; do
        if [[ -L "$file" ]]; then
            DYLIBS+=("$file")
        fi
    done
    cd $WORKING_DIR

    for exe in $EXES; do
        for dylib in $DYLIBS; do
            install_name_tool -change $OUT_DIR/lib/$dylib @executable_path/../lib/$dylib $OUT_DIR/bin/$exe
            checkStatus $? "dylib relocating failed"
        done
    done
}