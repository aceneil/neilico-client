# Build guide / 构建说明

[English README](../README.md) | [简体中文 README](../README.zh-CN.md)

This document collects the longer build details referenced by the root READMEs.

本文汇总根 README 引用的详细构建信息。

## Toolchain / 工具链

**English:** Use Flutter 3.24.5 and Rust 1.75. `Cargo.toml` pins the minimum Rust version, while the NEILICO build workflows use Rust 1.75 and Flutter 3.24.5. Flutter Rust Bridge generation uses the repository's pinned bridge workflow and version.

**简体中文：** 使用 Flutter 3.24.5 和 Rust 1.75。`Cargo.toml` 固定 Rust 最低版本，NEILICO 构建工作流使用 Rust 1.75 与 Flutter 3.24.5。Flutter Rust Bridge 生成使用仓库固定的 bridge 工作流和版本。

## Core build / 核心构建

**English:** From the repository root, build the Rust core with the requested features, then build the Flutter Windows app:

```bash
cargo build --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

CI may add `--locked --release` for reproducible release jobs. `hwcodec` and `vram` require the appropriate codec and vcpkg dependencies.

**简体中文：** 在仓库根目录先构建带指定 feature 的 Rust 核心，再构建 Flutter Windows 应用：

```bash
cargo build --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

CI 的可复现发布任务可能额外使用 `--locked --release`。`hwcodec` 和 `vram` 需要对应的编解码与 vcpkg 依赖。

## Server injection / 服务器注入

**English:** Set both build-time variables before compiling:

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --features "flutter,hwcodec,vram"
```

CI maps repository variable `vars.NEILICO_ID_SERVER` and secret `secrets.NEILICO_PUB_KEY` into these environment variables. If either value is absent, the source placeholders `your-server.example.com` and `YOUR_HBBS_PUBLIC_KEY` remain in the build. Such a build cannot connect to any server. Use the public key from `id_ed25519.pub`; never place the private key in the repository or client.

**简体中文：** 编译前设置两个构建期变量：

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --features "flutter,hwcodec,vram"
```

CI 把仓库变量 `vars.NEILICO_ID_SERVER` 和 secret `secrets.NEILICO_PUB_KEY` 映射到上述环境变量。缺少任一值时，构建会保留源码占位符 `your-server.example.com` 和 `YOUR_HBBS_PUBLIC_KEY`，这种产物连不上任何服务器。公钥来自 `id_ed25519.pub`；私钥不得进入仓库或客户端。

## CI locations / CI 位置

| File / 文件 | Purpose / 用途 |
| :-- | :-- |
| [`../.github/workflows/neilico-build.yml`](../.github/workflows/neilico-build.yml) | NEILICO Windows-priority three-platform build; Linux and macOS may currently fail and are not release acceptance targets. / NEILICO Windows 优先的三平台构建；Linux/macOS 当前允许失败，不作为发布验收目标。 |
| [`../.github/workflows/bridge.yml`](../.github/workflows/bridge.yml) | Reusable Flutter Rust Bridge generation steps. / 可复用的 Flutter Rust Bridge 生成步骤。 |
| [`../.github/workflows/flutter-build.yml`](../.github/workflows/flutter-build.yml) | Upstream multi-platform Flutter build implementation and platform dependency setup. / 上游多平台 Flutter 构建实现和平台依赖准备。 |
| [`../.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml) | Full Flutter CI entry point. / 完整 Flutter CI 入口。 |

**English:** The NEILICO Windows job uses Windows Server 2022, LLVM 15.0.6, vcpkg, and the RustDesk custom Flutter engine. It generates bridge files before compiling the Rust core and Flutter application.

**简体中文：** NEILICO Windows 任务使用 Windows Server 2022、LLVM 15.0.6、vcpkg 和 RustDesk 自定义 Flutter engine；先生成 bridge 文件，再编译 Rust 核心和 Flutter 应用。
