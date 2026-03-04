# FFmpeg 构建脚本 (跨平台 & 高性能优化版)

[English](README.md) | 中文

这是一个高度优化、自动化的 FFmpeg 构建脚本，完美支持 **Linux** 和 **macOS (Apple Silicon & Intel)**。

本项目是基于 [Martin Riedl](https://gitlab.com/martinr92) 的原始脚本以及 [Hayden Zheng (MiKayule)](https://www.google.com/search?q=https://github.com/MiKayule) 修改版的分支。上游版本引入了 PGO/LTO 优化（主要针对 macOS），而**本分支**在此基础上进行了重构，恢复了对 Linux 的完整支持，添加了新特性，并优化了 CI/CD 流程。

## 📥 预编译二进制文件 (下载即用)

不想从源码手动编译？
您可以直接前往 **[GitHub Releases](https://github.com/MIKU552/ffmpeg-build-mika/releases)** 页面下载适用于 **Linux** 和 **macOS** 的最新预编译版本。这些构建文件均由我们的 CI 流水线自动生成。

## ✨ 核心特性与变更

* **🔧 跨平台修复与统一**：
* 修复了因上游过度针对 macOS 优化而导致的 Linux 构建中断问题。
* 统一使用 `build_fix.sh` 作为入口，自动检测操作系统并适配正确的编译器参数和库路径。


* **⚡ 增量编译 (热启动)**：
* 引入智能检测机制：编译前会检查 `tool/lib` 下是否存在已编译好的库。如果存在，脚本将自动跳过该库的编译。这实现了极速的“热启动”，方便在调试或添加新组件时无需重新编译整个依赖树。


* **🚀 硬件加速支持**：
* **Linux**: 新增 `VAAPI`、`Vulkan` 和 `libdrm` 支持。
* **macOS**: 保留原有的 `VideoToolbox` 和 `AudioToolbox` 支持。


* **📦 新增组件支持**：
* **Whisper**: 集成 `libwhisper` (Whisper.cpp)，支持 AI 语音转文字。
* **FDK-AAC**: 集成最高质量的 AAC 编码器。
* **Soxr**: 集成高质量音频重采样库。


* **📉 PGO 流程优化**：
* 移除了 PGO 训练样本对 Git LFS 的依赖。样本文件现在通过外链下载，或者在缺失时自动跳过训练，彻底解决了 Git LFS 流量超额或下载失败导致构建报错的问题。


* **🤖 自动化 CI/CD**：
* 编写了生产级的 GitHub Actions 配置。
* 支持在版本更新或手动触发时，**一键并发编译** macOS 和 Linux 版本，并自动发布 Release。



## 📦 包含的编解码器与库

| 类别 | 组件 / 库 |
| --- | --- |
| **视频 (VVC)** | `vvenc` (编码器), `vvdec` (解码器) - *含自动 Patch 修复* |
| **视频 (AV1)** | `rav1e`, `svt-av1` (编码器), `dav1d` (解码器), `libaom` |
| **视频 (HEVC)** | `x265` (支持 8bit/10bit/12bit 多位深) |
| **视频 (H.264)** | `x264`, `openh264` |
| **音频** | **`fdk-aac`**, **`libsoxr`**, `mp3lame`, `opus`, `vorbis` |
| **AI / 语音** | **`libwhisper`** (Whisper.cpp) |
| **硬件加速** | **Linux**: VAAPI, Vulkan, DRM<br>**macOS**: VideoToolbox |
| **字幕与滤镜** | `libass`, `zimg`, `libvmaf`, `freetype`, `harfbuzz`, `fribidi` |

## 🛠️ 编译指南

### 1. 安装依赖

请确保您的系统已安装必要的构建工具。

**Linux (Debian / Ubuntu):**

*需要安装 Vulkan SDK 以支持硬件加速。*

```bash
# 1. 添加 LunarG Vulkan SDK 源
wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | sudo tee /etc/apt/trusted.gpg.d/lunarg.asc
sudo wget -qO /etc/apt/sources.list.d/lunarg-vulkan-noble.list http://packages.lunarg.com/vulkan/lunarg-vulkan-noble.list
sudo apt-get update

# 2. 安装系统依赖
sudo apt-get install -y --no-install-recommends \
    build-essential gcc g++ binutils make cmake ninja-build pkg-config \
    curl wget patch tar gzip bzip2 xz-utils zip python3 python3-pip \
    python3-venv python3-virtualenv nasm git-lfs docbook-utils \
    xsltproc asciidoc xmlto gperf autopoint automake libtool autoconf \
    gettext liblzma-dev libnuma-dev libssl-dev ccache \
    libva-dev libdrm-dev vulkan-sdk

# 3. 安装 Rust (构建 rav1e/svt-av1/cargo-c 需要)
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
cargo install cargo-c --version 0.10.20 --locked

```

**macOS:**

```bash
brew update
brew install automake libtool cmake ninja nasm pkg-config ccache wget xz

# 安装 Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
cargo install cargo-c --version 0.10.20 --locked

```

### 2. 开始编译

脚本**不会**自动创建构建目录。为了保持源码目录整洁，您必须手动创建一个构建目录。

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/ffmpeg-build-mika.git
cd ffmpeg-build-mika

# 2. 创建并进入构建目录
mkdir build
cd build

# 3. 运行构建脚本 (注意使用相对路径指向脚本)
# 常用参数：
# -SKIP_BUNDLE=NO: 构建完成后打包为 .tar.gz (Linux) 或 .zip (macOS)
# -SKIP_TEST=YES: 跳过耗时的测试环节
../build_fix.sh -SKIP_BUNDLE=NO -SKIP_TEST=YES

```

由于实现了**增量编译**特性，如果脚本检测到 `tool/lib` 下已经存在某个库（例如 `x264`），它会自动跳过该库的编译。如果需要强制重编特定组件，请删除 `build` 目录或手动删除 `tool/` 下的对应文件。

### 3. 构建参数

您可以通过向 `build_fix.sh` 传递参数来定制构建过程：

* **性能优化**:
* `-ENABLE_FFMPEG_PGO=YES`: 开启 Profile-Guided Optimization (PGO)。这会编译 FFmpeg 两次（插桩运行 -> 训练 -> 优化编译）。构建时间会显著增加，但能带来更好的运行时性能。


* **功能开关**:
* `-SKIP_WHISPER=YES`: 跳过 Whisper AI 模型支持。
* `-SKIP_DECKLINK=NO`: 开启 Blackmagic Decklink 支持（需通过 `-DECKLINK_SDK=...` 提供 SDK 路径）。
* `-SKIP_VVENC=YES`: 跳过 VVC 编码器。


* **版本控制**:
* `-FFMPEG_SNAPSHOT=NO`: 构建 `version/ffmpeg` 文件中定义的特定 Release 版本，而不是最新的 Snapshot 代码。



## 📂 输出产物

构建成功后，`build/out` 目录将包含：

* `bin/` : 可执行文件 (`ffmpeg`, `ffplay`, `ffprobe`)。
* `lib/` : 动态链接库。
* `include/` : 头文件。
* `ffmpeg-build-*.tar.gz` (Linux) 或 `*.zip` (macOS)。

> **macOS 用户注意**：脚本会自动处理 dylib 的路径重定位（Relocation），生成的压缩包是完全**便携 (Portable)** 的，解压后可在任何目录下直接运行。

## 📜 鸣谢

* **Martin Riedl**: 构建脚本架构的原始作者。
* **Hayden Zheng (MiKayule)**: 引入了 PGO/LTO 优化及初期的 VVC 支持。
* **本分支**: 实现了跨平台修复、增量编译、硬件加速集成及 CI 自动化。

## ⚖️ 许可协议

本项目遵循 **Apache License 2.0** 协议。
详见 [LICENSE](https://www.google.com/search?q=LICENSE) 文件。