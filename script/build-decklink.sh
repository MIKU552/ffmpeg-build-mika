#!/bin/bash

# Copyright 2023 Martin Riedl
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

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
TOOL_DIR=$2
DECKLINK_SDK=$3

# load functions
. $SCRIPT_DIR/functions.sh

# check decklink folder
cd $DECKLINK_SDK
checkStatus $? "change directory failed"
if [ -f "DeckLinkAPI.h" ]; then
    echo "decklink SDK found"
else
    echo "decklink SDK not found"
    exit 1
fi

# copy SDK
cp * "$TOOL_DIR/include"
checkStatus $? "copy SDK failed"
