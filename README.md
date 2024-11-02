# FFmpeg Build Script for macOS
This script was made to compile FFmpeg with common codecs on Linux and macOS by Martin Riedl @martinr92. I made the FFmpeg compiled by this script a shared one, with LTO and PGO (currently for x265, SVT-AV1, vvenc, vvdec) optimization, focusing on CLI usage and achieving the best performance possible.

## Compatibility with Linux
This script is currently not compatible with Linux, because of the difference in sed's syntax, clang/gnu, and the behavior of CMake. I will try to work on it later after finishing my main development goals.

## Looking for the pre-compiled result? (Without VVC codecs and optimizations)
Check out the [build server](https://ffmpeg.martin-riedl.de). Here you can download builds for Linux and macOS.

## Result
This repository builds FFmpeg, FFprobe and FFplay using
- build tools
    - [cmake](https://cmake.org/)
    - [nasm](http://www.nasm.us/)
    - [ninja](https://ninja-build.org/)
    - [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/)
- libraries
    - [libass](https://github.com/libass/libass) for subtitle rendering
    - [libbluray](https://www.videolan.org/developers/libbluray.html) for container format bluray
    - [decklink](https://www.blackmagicdesign.com/developer/) for Blackmagicdesign hardware
    - [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/)
    - [FreeType](https://freetype.org)
    - [FriBidi](https://github.com/fribidi/fribidi)
    - [harfbuzz](https://github.com/harfbuzz/harfbuzz)
    - [libiconv](https://www.gnu.org/software/libiconv/)
    - [libklvanc](https://github.com/stoth68000/libklvanc)
    - [libogg](https://xiph.org/ogg/) for container format ogg
    - [openssl](https://www.openssl.org/)
    - [SDL](https://www.libsdl.org/) for ffplay
    - [snappy](https://github.com/google/snappy/) for HAP encoding
    - [srt](https://github.com/Haivision/srt) for protocol srt
    - [libvmaf](https://github.com/Netflix/vmaf/tree/master/libvmaf) for VMAF video filter
    - [libxml2](http://xmlsoft.org)
    - [zimg](https://github.com/sekrit-twc/zimg)
    - [zlib](https://www.zlib.net) for png format
    - [zvbi](https://sourceforge.net/projects/zapping/) for teletext decoding
- video codecs
    - [aom](https://aomedia.org/) for AV1 de-/encoding
    - [dav1d](https://www.videolan.org/projects/dav1d.html) for AV1 decoding
    - [openh264](https://www.openh264.org/) for H.264 de-/encoding
    - [OpenJPEG](http://www.openjpeg.org/) for JPEG de-/encoding
    - [rav1e](https://github.com/xiph/rav1e) for AV1 encoding
    - [svt-av1](https://gitlab.com/AOMediaCodec/SVT-AV1) for AV1 encoding
    - [libtheroa](https://www.theora.org) for theora encoding
    - [vpx](https://www.webmproject.org/) for VP8/VP9 de-/encoding
    - [libwebp](https://www.webmproject.org/) for webp encoding
    - [x264](http://www.videolan.org/developers/x264.html) for H.264 encoding
    - [x265](https://www.videolan.org/developers/x265.html) for H.265/HEVC encoding (8bit+10bit+12bit)
    - [vvenc](https://github.com/fraunhoferhhi/vvenc) for H.266/VVC encoding
    - [vvdec](https://github.com/fraunhoferhhi/vvdec) for H.266/VVC decoding
- audio codecs
    - [LAME](http://lame.sourceforge.net/) for MP3 encoding
    - [opus](https://opus-codec.org/) for Opus de-/encoding
    - [libvorbis](https://xiph.org/vorbis/) for vorbis de-/encoding

To get a full list of all formats and codecs that are supported just execute
```
./ffmpeg -formats
./ffmpeg -codecs
```

## Requirements
There are just a few dependencies to other tools. Most of the software is compiled or downloaded during script execution. Also most of the tools should be already available on the system by default.

### Linux
- gcc (c and c++ compiler)
- curl
- make
- zip, bunzip2
- rust / cargo / cargo-c
- python3 (including pip virtualenv)

### macOS
- [Xcode](https://apps.apple.com/de/app/xcode/id497799835)
- rust / cargo / cargo-c
- python3 (including pip virtualenv)

### Windows (not supported)
For compilation on Windows please use `MSYS2`. Follow the whole instructions for installation (including step 7).
- [MSYS2](https://www.msys2.org/)

## Execution
> ### Note
> The PGO training process of vvenc runs very slowly. If it is way too slow for you, you can choose a lighter PGO training process for vvenc. Please follow the comments in `script/build-vvenc.sh`.

All files that are downloaded and generated through this script are placed in the current working directory. The recommendation is to use an empty folder for this and execute the `build.sh`.
```sh
mkdir ffmpeg-compile
cd ffmpeg-compile
../build.sh
```

You can use the following parameters
- `-FFMPEG_SNAPSHOT=YES` for using the latest snapshot of FFmpeg instead of the last release
- `-SKIP_TEST=YES` for skipping the tests after compiling
- `-SKIP_BUNDLE=YES` for skipping creating the `ffmpeg-success.zip` file
- `-CPU_LIMIT=num` for limit CPU thread usage (default: automatically detected)

If you don't need a codec/library, you can also disable them:
- libraries
    - `-SKIP_LIBKLVANC=YES`
    - `-SKIP_LIBBLURAY=YES`
    - `-SKIP_SNAPPY=YES`
    - `-SKIP_SRT=YES`
    - `-SKIP_LIBVMAF=YES`
    - `-SKIP_ZIMG=YES`
    - `-SKIP_ZVBI=YES`
- video codecs
    - `-SKIP_AOM=YES`
    - `-SKIP_DAV1D=YES`
    - `-SKIP_OPEN_H264=YES`
    - `-SKIP_OPEN_JPEG=YES`
    - `-SKIP_RAV1E=YES`
    - `-SKIP_SVT_AV1=YES`
    - `-SKIP_LIBTHEORA=YES`
    - `-SKIP_VPX=YES`
    - `-SKIP_LIBWEBP=YES`
    - `-SKIP_X264=YES`
    - `-SKIP_X265=YES`
    - `-SKIP_X265_MULTIBIT=YES`
- audio codecs
    - `-SKIP_LAME=YES`
    - `-SKIP_OPUS=YES`
    - `-SKIP_LIBVORBIS=YES`

After the execution a new folder called `out` exists. It contains the compiled FFmpeg binary (in the `bin` sub-folder).
The `ffmpeg-success.zip` contains also all binary files of FFmpeg, FFprobe and FFplay.

### Decklink
It is required to prepare the Blackmagic Decklink SDK manually, because a automated download is not possible.
Download the SDK manually from the [Blackmagic Website](https://www.blackmagicdesign.com/developer/) and extract the compressed file.
Then add the following parameters (for the SDK include location):
```sh
-DECKLINK_SDK=/path/to/SDK/os/include -SKIP_DECKLINK=NO
```

## Validate Build
### Dynamic Linking
You can check dynamically linked libraries using the follwing command:
```
# macOS
otool -L out/bin/ffmpeg

# linux
ldd out/bin/ffmpeg
```

## Build failed?
Check the detailed logfiles in the `log` directory. Each build step has its own file starting with "build-*".

If the build of ffmpeg failes during the configuration phase (e.g. because it doesn't find one codec) check also the log file in `source/ffmpeg/ffmpeg-*/ffbuild/config.log`.

# License
Copyright 2021 Martin Riedl
Copyright 2024 Hayden Zheng

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
