#!/bin/sh
# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs
# $5 = libvpx version

# load functions
. $1/functions.sh

# start in working directory
cd "$2"
checkStatus $? "change directory failed"
mkdir "vpx"
checkStatus $? "create directory failed"
cd "vpx/"
checkStatus $? "change directory failed"

# download source
curl -o vpx.tar.gz -L https://github.com/webmproject/libvpx/archive/v$5.tar.gz
checkStatus $? "download of vpx failed"

# TODO: checksum validation (if available)

# unpack
tar -zxf "vpx.tar.gz"
checkStatus $? "unpack vpx failed"
cd "libvpx-$5/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$3" --disable-unit-tests
checkStatus $? "configuration of vpx failed"

# build
make -j $4
checkStatus $? "build of vpx failed"

# install
make install
checkStatus $? "installation of vpx failed"
