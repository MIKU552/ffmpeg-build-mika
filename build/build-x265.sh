#!/bin/sh
# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs
# $5 = x265 version

# load functions
. $1/functions.sh

# start in working directory
cd "$2"
checkStatus $? "change directory failed"
mkdir "x265"
checkStatus $? "create directory failed"
cd "x265/"
checkStatus $? "change directory failed"

# download source
curl -O -L https://bitbucket.org/multicoreware/x265/downloads/x265_$5.tar.gz
checkStatus $? "download of x265 failed"

# TODO: checksum validation (if available)

# unpack
tar -zxf "x265_$5.tar.gz"
checkStatus $? "unpack x265 failed"
cd "x265_$5/"
checkStatus $? "change directory failed"

# prepare build
cmake -DCMAKE_INSTALL_PREFIX:PATH=$3 -DENABLE_SHARED=NO source
checkStatus $? "configuration of x265 failed"

# build
make -j $4
checkStatus $? "build of x265 failed"

# install
make install
checkStatus $? "installation of x265 failed"

# post-installation
# modify pkg-config file for usage with ffmpeg (it seems that the flag for threads is missing)
sed -i.original -e 's/lx265/lx265 -lpthread/g' $3/lib/pkgconfig/x265.pc
