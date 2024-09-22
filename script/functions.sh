#!/bin/sh

# Copyright 2021 Martin Riedl
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
    TIME_GDATE=$(date +%s)
    if [ $? -eq 0 ]
    then
        echo $TIME_GDATE
    else
        echo 0
    fi
}

echoDurationInSections(){
    END_TIME=$(currentTimeInSeconds)
    echo "took $(($END_TIME - $1))s"
}

download(){
    URL=$1
    NAME=$2
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
