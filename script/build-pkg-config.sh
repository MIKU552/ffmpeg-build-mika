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

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/pkg-config")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "pkg-config"
checkStatus $? "create directory failed"
cd "pkg-config/"
checkStatus $? "change directory failed"

# download source
download https://pkg-config.freedesktop.org/releases/pkg-config-$VERSION.tar.gz "pkg-config.tar.gz"
checkStatus $? "download of pkg-config failed"

# unpack
tar -zxf "pkg-config.tar.gz"
checkStatus $? "unpack pkg-config failed"
cd "pkg-config-$VERSION/"
checkStatus $? "change directory failed"

# windows specific stuff
DETECTED_OS="$(uname -o 2> /dev/null)"
echo "detected OS: $DETECTED_OS"
if [ $DETECTED_OS = "Msys" ]; then
    # download patches
    # https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-pkg-config
    echo "download patches for windows"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch "1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch"
    checkStatus "download of patch 1001 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1003-g_abort.all.patch "1003-g_abort.all.patch"
    checkStatus "download of patch 1003 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch "1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch"
    checkStatus "download of patch 1005 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1017-glib-use-gnu-print-scanf.patch "1017-glib-use-gnu-print-scanf.patch"
    checkStatus "download of patch 1017 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1024-return-actually-written-data-in-printf.all.patch "1024-return-actually-written-data-in-printf.all.patch"
    checkStatus "download of patch 1024 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1030-fix-stat.all.patch "1030-fix-stat.all.patch"
    checkStatus "download of patch 1030 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1031-fix-glib-gettext-m4-error.patch "1031-fix-glib-gettext-m4-error.patch"
    checkStatus "download of patch 1031 failed"

    # patch fixes for windows build
    cd glib
    echo "apply patches for windows"
    patch -Np1 -i "../1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch"
    checkStatus "apply patch 1001 failed"
    patch -Np1 -i "../1003-g_abort.all.patch"
    checkStatus "apply patch 1003 failed"
    patch -Np1 -i "../1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch"
    checkStatus "apply patch 1005 failed"
    patch -Np1 -i "../1017-glib-use-gnu-print-scanf.patch"
    checkStatus "apply patch 1017 failed"
    patch -Np1 -i "../1024-return-actually-written-data-in-printf.all.patch"
    checkStatus "apply patch 1024 failed"
    patch -Np1 -i "../1030-fix-stat.all.patch"
    checkStatus "apply patch 1030 failed"
    patch -Np1 -i "../1031-fix-glib-gettext-m4-error.patch"
    checkStatus "apply patch 1031 failed"
    cd ..
fi

# prepare build
./configure --prefix="$TOOL_DIR" --with-pc-path="$TOOL_DIR/lib/pkgconfig" --with-internal-glib CFLAGS="-Wno-int-conversion"
checkStatus $? "configuration of pkg-config failed"

# build
make
checkStatus $? "build of pkg-config failed"

# install
make install
checkStatus $? "installation of pkg-config failed"
