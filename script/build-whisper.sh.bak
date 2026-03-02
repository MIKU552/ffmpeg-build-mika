#!/bin/bash
# script/build-whisper.sh

# ---
# Functions
# ---
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
# shellcheck source=../script/functions.sh
. "$SCRIPT_DIR/functions.sh"

# ---
# Main
# ---

# Arguments
SCRIPT_DIR="$1"
SOURCE_DIR="$2"
TOOL_DIR="$3"
CPUS="$4"

# Get source code
WHISPER_SOURCE_DIR="$SOURCE_DIR/whispercpp"
if [ ! -d "$WHISPER_SOURCE_DIR/.git" ]; then
    echo "Cloning whisper.cpp source..."
    rm -rf "$WHISPER_SOURCE_DIR"
    git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_SOURCE_DIR"
    checkStatus $? "Failed to clone whisper.cpp"
else
    echo "whisper.cpp source directory already exists. Pulling latest changes..."
    cd "$WHISPER_SOURCE_DIR" || exit 1
    git pull
    checkStatus $? "Failed to pull whisper.cpp"
fi

# Build and install
cd "$WHISPER_SOURCE_DIR" || exit 1
# Clean old build
rm -rf build
mkdir build && cd build

# Configure with CMake
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$TOOL_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF

checkStatus $? "whisper.cpp cmake configure failed"

# Compile and install
make -j"$CPUS"
checkStatus $? "whisper.cpp make failed"

make install
checkStatus $? "whisper.cpp make install failed"

# --- Post-installation pkg-config fix (解决 FFmpeg 找不到 whisper 的问题) ---
echo "Applying post-installation fix to whisper.pc for static linking..."
WHISPER_PC="$TOOL_DIR/lib/pkgconfig/whisper.pc"
if [ -f "$WHISPER_PC" ]; then
    echo "Found pkgconfig file at: $WHISPER_PC"
    # whisper.cpp 是 C++ 编写且使用了 OpenMP，并被拆分成了多个 ggml 子库。
    # 这里我们使用跨平台的 run_sed 强行把所有隐藏依赖补齐，以骗过 FFmpeg 的探测。
    run_sed "s|-lwhisper|-lwhisper -lggml -lggml-cpu -lggml-base -lstdc++ -fopenmp -lm -lpthread|g" "$WHISPER_PC"
    checkStatus $? "modify pkgconfig file failed"
    echo "Dependencies successfully added to $WHISPER_PC"
else
    echo "Warning: whisper.pc not found!"
fi