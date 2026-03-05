# FFmpeg 编译脚本 (跨平台 & 极致优化版)

[English](README.md) | 中文

一个高度优化、全自动的 FFmpeg 编译脚本，支持 **Linux** 和 **macOS (Apple Silicon & Intel)**。

本项目是基于 [Martin Riedl](https://gitlab.com/martinr92) 和 [Hayden Zheng (MiKayule)](https://github.com/MiKayule) 工作成果的深度重构分支。之前的版本虽然引入了基础的 PGO/LTO 优化，但**本分支对整个构建架构进行了彻底的重写**。它不仅实现了真正的跨平台稳定，解决了 Linux 环境下灾难性的原子锁竞争 Bug，还引入了先进的多进程 PGO 训练管线，新增了前沿的 AI 与音频组件，并完全打通了 CI/CD 自动化流程。

## 📥 预编译程序 (开箱即用)

不想从源码自己编译？
您可以直接前往 **[GitHub Releases](https://github.com/MIKU552/ffmpeg-build-mika/releases)** 页面，下载最新的 **Linux** 和 **macOS** 预编译可执行文件。这些版本由我们的 CI 自动构建，并且已经**满血注入了 PGO 极致优化**。

## 🎯 PGO 优化目标 (核心黑科技)

与普通的常规编译不同，本仓库中的核心视频编码器（`x265`、`SVT-AV1`、`VVenC`）在编译阶段均使用了**配置文件引导优化 (PGO)**，且这些优化是**专门为极致画质、慢速压制场景（如动漫、典藏、电影压制）量身定制的**。

在编译过程中，我们向编译器喂入了极高强度的测试负载，迫使它深度分析并优化最底层的运动搜索和宏块划分的 C/汇编代码分支。如果您日常的压制参数与以下参数匹配或相似，您将体验到这些编码器所能提供的**理论最高性能**：

* **`x265` (HEVC) 训练参数:**
```text
--preset veryslow --crf 28 --rc-lookahead 250 --open-gop

```


* **`SVT-AV1` (AV1) 训练参数:**
```text
--preset 2 --lookahead 120 --tune 0

```


* **`VVenC` (VVC/H.266) 训练参数:**
```text
--preset 3 -q 26

```



## ✨ 核心特性 & 深度重构

* **📉 先进的 PGO 工作流**:
* 彻底重构了稳健且跨平台的 PGO 管线。它可以智能处理 CI 上的并发训练任务，在不卡死或崩溃的前提下，生成极高精度的性能剖析数据。
* 移除了 PGO 训练样本对 Git LFS 的依赖。测试样本现改为通过外部链接下载，缺失时自动跳过，彻底杜绝了 Git LFS 配额超限报错。


* **🔧 跨平台兼容性修复**:
* 修复了之前因强行套用 macOS 优化代码而导致 Linux 平台编译中断的问题。
* 统一了入口脚本 (`build_fix.sh`)，能够自动检测操作系统并应用完全匹配当前平台的编译器参数、链接器标志和宏抑制指令。


* **⚡ 增量编译 (热启动)**:
* 实现了智能检测机制：如果在 `tool/lib` 中检测到已编译好的库文件，后续重新运行脚本时将自动跳过该组件。在调试或新增组件时，允许快速“热启动”，无需痛苦地重新编译整个依赖树。


* **🚀 硬件加速集成**:
* **Linux**: 增加了对 `VAAPI`、`Vulkan` 和 `libdrm` 的支持。
* **macOS**: 保留并完善了原有的 `VideoToolbox` 和 `AudioToolbox` 支持。


* **📦 全新现代组件**:
* **Whisper**: 集成了 `libwhisper` (Whisper.cpp)，支持利用 AI 进行硬件加速的语音转文本识别。
* **FDK-AAC & Soxr**: 引入了工业级的高质量音频编码器和顶级重采样库。


* **🤖 自动化 CI/CD**:
* 配备了强大的 GitHub Actions 工作流。能够轻松应对 PGO 训练带来的极限高负载，在版本更新时自动、并发地完成 **macOS** 和 **Linux** 双平台的构建与发布。



## 📦 包含的编解码器与库

| 类别 | 包含组件 |
| --- | --- |
| **视频 (VVC)** | `vvenc` (编码器), `vvdec` (解码器) - *已自动应用 Patch* |
| **视频 (AV1)** | `rav1e`, `svt-av1` (编码器), `dav1d` (解码器), `libaom` |
| **视频 (HEVC)** | `x265` (完美链接 8/10/12bit 多位深支持) |
| **视频 (H.264)** | `x264`, `openh264` |
| **音频** | **`fdk-aac`**, **`libsoxr`**, `mp3lame`, `opus`, `vorbis` |
| **AI / 语音** | **`libwhisper`** (Whisper.cpp) |
| **硬件加速** | **Linux**: VAAPI, Vulkan, DRM<br>

<br>**macOS**: VideoToolbox |
| **滤镜与字幕** | `libass`, `zimg`, `libvmaf`, `freetype`, `harfbuzz`, `fribidi` |

## 🛠️ 编译指南

### 1. 安装依赖

请确保您的系统已经安装了必要的构建工具。

**Linux (Debian / Ubuntu):**

*注意：需要安装 Vulkan SDK 以提供相关的硬件加速支持。*

```bash
# 1. 添加 LunarG Vulkan SDK 仓库
wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | sudo tee /etc/apt/trusted.gpg.d/lunarg.asc
sudo wget -qO /etc/apt/sources.list.d/lunarg-vulkan-noble.list http://packages.lunarg.com/vulkan/lunarg-vulkan-noble.list
sudo apt-get update

# 2. 安装系统级依赖
sudo apt-get install -y --no-install-recommends \
    build-essential gcc g++ binutils make cmake ninja-build pkg-config \
    curl wget patch tar gzip bzip2 xz-utils zip python3 python3-pip \
    python3-venv python3-virtualenv nasm git-lfs docbook-utils \
    xsltproc asciidoc xmlto gperf autopoint automake libtool autoconf \
    gettext liblzma-dev libnuma-dev libssl-dev ccache \
    libva-dev libdrm-dev vulkan-sdk

# 3. 安装 Rust (rav1e/svt-av1/cargo-c 需要)
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

本脚本**不会**自动创建构建目录。您必须手动创建一个构建目录，以确保源码树的干净整洁。

```bash
# 1. 克隆本仓库
git clone https://github.com/your-username/ffmpeg-build-mika.git
cd ffmpeg-build-mika

# 2. 创建并进入 build 目录
mkdir build
cd build

# 3. 运行构建脚本 (注意使用相对路径)
# 常用参数说明:
# -SKIP_BUNDLE=NO: 构建完成后将产物打包成 .tar.gz (Linux) 或 .zip (macOS)
# -SKIP_TEST=YES: 跳过编译后的测试环节 (大幅节省时间)
../build_fix.sh -SKIP_BUNDLE=NO -SKIP_TEST=YES

```

得益于**增量编译**特性，如果脚本在 `tool/lib` 中找到了某个库（例如 `x264`），它将自动跳过该库的编译阶段。如需强制重新编译特定组件，请直接删除 `build` 目录，或者清空 `tool/` 目录下的相应产物。

### 3. 自定义构建参数

您可以通过向 `build_fix.sh` 传递附加参数来自定义构建过程：

* **性能优化**:
* `-ENABLE_FFMPEG_PGO=YES`: 开启对 FFmpeg 核心程序本身的 PGO 优化。*(注意：`x265`、`SVT-AV1` 和 `VVenC` 等核心编码引擎在它们各自独立的构建脚本中已经默认开启了极致级别的 PGO 优化，不受此选项影响)*。


* **功能开关**:
* `-SKIP_WHISPER=YES`: 跳过构建 Whisper AI 模型组件。
* `-SKIP_DECKLINK=NO`: 启用 Blackmagic Decklink 采集卡支持（需要您通过 `-DECKLINK_SDK=...` 显式提供 SDK 路径）。
* `-SKIP_VVENC=YES`: 跳过 VVC 编码器组件的编译。


* **版本控制**:
* `-FFMPEG_SNAPSHOT=NO`: 编译定义在 `version/ffmpeg` 文件中的特定发布版本，而非使用最新的 Master 分支快照。



## 📂 编译输出

构建成功后，您的 `build` 文件夹内将生成一个 `out` 目录，其中包含：

* `bin/` : 静态链接的可执行文件 (如 `ffmpeg`, `ffplay`, `ffprobe`, `vvencapp` 等)。
* `lib/` : 静态/共享库文件。
* `include/` : C/C++ 头文件。
* `ffmpeg-build-*.tar.gz` (Linux) 或 `*.zip` (macOS) 便携压缩包。

> **关于便携性 (Portability) 的说明**: **macOS** 和 **Linux** 的构建产物均是完全便携的“绿色版”。脚本在底层自动处理了动态库的相对路径重定位（macOS 使用 `@executable_path`，Linux 使用基于 `$ORIGIN` 的 RPATH 注入）。生成的压缩包（`.zip` 或 `.tar.gz`）解压后，即可在系统的任何目录下直接运行，彻底告别繁琐的 `LD_LIBRARY_PATH` 环境变量配置！

## 📜 鸣谢

* **Martin Riedl**: 制定了本构建脚本系统的最初基础架构。
* **Hayden Zheng (MiKayule)**: 引入了早期的 PGO/LTO 优化策略，以及最初的 VVC 编解码器支持。
* **This Branch (本分支)**: 实现了真正的跨平台 PGO 架构，修复了 Linux 下导致死锁的原子锁并发 Bug，精准匹配 Clang 模板可见性问题，引入了增量编译、硬件加速深度集成以及高强度的 CI 全自动化。

## ⚖️ 许可证

基于 **Apache License, Version 2.0** 许可。
详情请参阅 [LICENSE](https://www.google.com/search?q=LICENSE) 文件。