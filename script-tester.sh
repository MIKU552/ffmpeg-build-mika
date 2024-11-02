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

# some folder names
BASE_DIR="$( cd "$( dirname "$0" )" > /dev/null 2>&1 && pwd )"
echo "base directory is ${BASE_DIR}"
SCRIPT_DIR="${BASE_DIR}/script"
echo "script directory is ${SCRIPT_DIR}"
WORKING_DIR="$( pwd )"
echo "working directory is ${WORKING_DIR}"
SOURCE_DIR="$WORKING_DIR/source"
echo "source code directory is ${SOURCE_DIR}"
LOG_DIR="$WORKING_DIR/log"
echo "logs code directory is ${LOG_DIR}"
TOOL_DIR="$WORKING_DIR/tool"
echo "tool directory is ${TOOL_DIR}"
OUT_DIR="$WORKING_DIR/out"
echo "output directory is ${OUT_DIR}"

# detect CPU threads (nproc for linux, sysctl for osx)
CPUS=1
if [ "$CPU_LIMIT" != "" ]; then
    CPUS=$CPU_LIMIT
else
    CPUS_NPROC="$(nproc 2> /dev/null)"
    if [ $? -eq 0 ]; then
        CPUS=$CPUS_NPROC
    else
        CPUS_SYSCTL="$(sysctl -n hw.ncpu 2> /dev/null)"
        if [ $? -eq 0 ]; then
            CPUS=$CPUS_SYSCTL
        fi
    fi
fi
