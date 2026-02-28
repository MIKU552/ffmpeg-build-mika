#!/bin/bash

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
TEST_DIR=$2
TEST_OUT_DIR=$3
OUT_DIR=$4
LOG_DIR=$5

# load functions
. $SCRIPT_DIR/functions.sh

# test freetype and harfbuzz
START_TIME=$(currentTimeInSeconds)
echoSection "run test freetype encoding"
$OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -frames:v 1 -vf "drawtext=fontfile=$TEST_DIR/NotoSans-Regular.ttf:text='Martin Riedl':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=(w-text_w)/2:y=(h-text_h)/2" "$TEST_OUT_DIR/test-freetype.jpeg" > "$TEST_OUT_DIR/test-freetype.log" 2>&1
checkStatus $? "test freetype"
echoDurationInSections $START_TIME

# TODO: test fontconfig
#START_TIME=$(currentTimeInSeconds)
#echoSection "run test fontconfig encoding"
#$OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -frames:v 1 -vf "drawtext=font='Sans':text='Martin Riedl':fontcolor=white:fontsize=24:box=1:boxcolor=black@0.5:boxborderw=5:x=(w-text_w)/2:y=(h-text_h)/2" "$TEST_OUT_DIR/test-fontconfig.png" > "$TEST_OUT_DIR/test-fontconfig.log" 2>&1
#checkStatus $? "test fontconfig"
#echoDurationInSections $START_TIME

# TODO: test libbluray
SKIP_LIBBLURAY=$(cat "$LOG_DIR/skip-libbluray")
checkStatus $? "load skip-libbluray failed"

# test hap (snappy)
SKIP_SNAPPY=$(cat "$LOG_DIR/skip-snappy")
checkStatus $? "load skip-snappy failed"
if [ $SKIP_SNAPPY = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test hap (snappy) encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "hap" -an "$TEST_OUT_DIR/test-hap-snappy.mov" > "$TEST_OUT_DIR/test-hap-snappy.log" 2>&1
    checkStatus $? "test hap (snappy)"
    echoDurationInSections $START_TIME
fi

# test libvmaf
SKIP_LIBVMAF=$(cat "$LOG_DIR/skip-libvmaf")
checkStatus $? "load skip-libvmaf failed"
if [ $SKIP_LIBVMAF = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test libvmaf filter"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -i "$TEST_DIR/test.mp4" -t 00:02 -lavfi libvmaf -f null - > "$TEST_OUT_DIR/test-libvmaf.log" 2>&1
    checkStatus $? "test libvmaf"
    echoDurationInSections $START_TIME
fi

# test zimg
SKIP_ZIMG=$(cat "$LOG_DIR/skip-zimg")
checkStatus $? "load skip-zimg failed"
if [ $SKIP_ZIMG = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test zimg filter"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -i "$TEST_DIR/test.mp4" -t 00:02 -vf "zscale=h=720:h=1280" -f null - > "$TEST_OUT_DIR/test-zimg.log" 2>&1
    checkStatus $? "test zimg"
    echoDurationInSections $START_TIME
fi

# test libass
START_TIME=$(currentTimeInSeconds)
echoSection "run test libass encoding"
$OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -vf "subtitles=$TEST_DIR/subtitle.srt" "$TEST_OUT_DIR/test-libass.mp4" > "$TEST_OUT_DIR/test-libass.log" 2>&1
checkStatus $? "test libass"
echoDurationInSections $START_TIME

# test aom av1
SKIP_AOM=$(cat "$LOG_DIR/skip-aom")
checkStatus $? "load skip-aom failed"
if [ $SKIP_AOM = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test aom av1 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libaom-av1" -cpu-used 8 -an "$TEST_OUT_DIR/test-aom-av1.mp4" > "$TEST_OUT_DIR/test-aom-av1.log" 2>&1
    checkStatus $? "test aom av1"
    echoDurationInSections $START_TIME
fi

# test openh264
SKIP_OPEN_H264=$(cat "$LOG_DIR/skip-openh264")
checkStatus $? "load skip-openh264 failed"
if [ $SKIP_OPEN_H264 = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test openh264 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libopenh264" -an "$TEST_OUT_DIR/test-openh264.mp4" > "$TEST_OUT_DIR/test-openh264.log" 2>&1
    checkStatus $? "test openh264"
    echoDurationInSections $START_TIME
fi

# test openJPEG
SKIP_OPEN_JPEG=$(cat "$LOG_DIR/skip-openJPEG")
checkStatus $? "load skip-openJPEG failed"
if [ $SKIP_OPEN_JPEG = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test openJPEG encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libopenjpeg" -an -frames:v 1 "$TEST_OUT_DIR/test-openJPEG.jpg" > "$TEST_OUT_DIR/test-openJPEG.log" 2>&1
    checkStatus $? "test openJPEG"
    echoDurationInSections $START_TIME
fi

# test rav1e
SKIP_RAV1E=$(cat "$LOG_DIR/skip-rav1e")
checkStatus $? "load skip-rav1e failed"
if [ $SKIP_RAV1E = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test rav1e encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "librav1e" -speed 10 -qp 200 -an "$TEST_OUT_DIR/test-rav1e.mp4" > "$TEST_OUT_DIR/test-rav1e.log" 2>&1
    checkStatus $? "test rav1e"
    echoDurationInSections $START_TIME
fi

# test vpx
SKIP_VPX=$(cat "$LOG_DIR/skip-vpx")
checkStatus $? "load skip-vpx failed"
if [ $SKIP_VPX = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test vp8 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libvpx" -an "$TEST_OUT_DIR/test-vp8.webm" > "$TEST_OUT_DIR/test-vp8.log" 2>&1
    checkStatus $? "test vp8"
    echoDurationInSections $START_TIME

    START_TIME=$(currentTimeInSeconds)
    echoSection "run test vp9 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libvpx-vp9" -an "$TEST_OUT_DIR/test-vp9.webm" > "$TEST_OUT_DIR/test-vp9.log" 2>&1
    checkStatus $? "test vp9"
    echoDurationInSections $START_TIME
fi

# test libwebp
SKIP_LIBWEBP=$(cat "$LOG_DIR/skip-libwebp")
checkStatus $? "load skip-libwebp failed"
if [ $SKIP_LIBWEBP = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test libwebp encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libwebp" -an "$TEST_OUT_DIR/test-libwebp.webp" > "$TEST_OUT_DIR/test-libwebp.log" 2>&1
    checkStatus $? "test libwebp"
    echoDurationInSections $START_TIME
fi

# test x264
SKIP_X264=$(cat "$LOG_DIR/skip-x264")
checkStatus $? "load skip-x264 failed"
if [ $SKIP_X264 = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test x264 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libx264" -an "$TEST_OUT_DIR/test-x264.mp4" > "$TEST_OUT_DIR/test-x264.log" 2>&1
    checkStatus $? "test x264"
    echoDurationInSections $START_TIME
fi

# test x265
SKIP_X265=$(cat "$LOG_DIR/skip-x265")
checkStatus $? "load skip-x265 failed"
if [ $SKIP_X265 = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test x265 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:v "libx265" -an "$TEST_OUT_DIR/test-x265.mp4" > "$TEST_OUT_DIR/test-x265.log" 2>&1
    checkStatus $? "test x265"
    echoDurationInSections $START_TIME
fi

# test lame mp3
SKIP_LAME=$(cat "$LOG_DIR/skip-lame")
checkStatus $? "load skip-lame failed"
if [ $SKIP_LAME = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test lame mp3 encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:a "libmp3lame" -vn "$TEST_OUT_DIR/test-lame.mp3" > "$TEST_OUT_DIR/test-lame.log" 2>&1
    checkStatus $? "test lame mp3"
    echoDurationInSections $START_TIME
fi

# test opus
SKIP_OPUS=$(cat "$LOG_DIR/skip-opus")
checkStatus $? "load skip-opus failed"
if [ $SKIP_OPUS = "NO" ]; then
    START_TIME=$(currentTimeInSeconds)
    echoSection "run test opus encoding"
    $OUT_DIR/bin/ffmpeg -i "$TEST_DIR/test.mp4" -c:a "libopus" -vn "$TEST_OUT_DIR/test-opus.opus" > "$TEST_OUT_DIR/test-opus.log" 2>&1
    checkStatus $? "test opus"
    echoDurationInSections $START_TIME
fi
