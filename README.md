# NEILICO Client

NEILICO 官方客户端是面向 Windows、Linux、macOS 和 Android 的多平台远程桌面客户端，基于 `rustdesk/rustdesk` 1.5.0 修改，整体适用 **AGPL-3.0**。仓库同时包含从主仓库迁入的 Flutter 设备/策略管理端（`app/`）和 `rust-core/` 内核接入骨架。

## 平台状态

| 平台 | 状态 | 当前交付 |
| :-- | :-- | :-- |
| Windows x64 | ✅ 已出包 | [Release v1.5.0-neilico.1](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) |
| Linux x64 | ⏳ 构建中 | `.github/workflows/neilico-build.yml` 手动构建、允许失败，尚无正式 Release |
| macOS | ⏳ 构建中 | `.github/workflows/neilico-build.yml` 手动构建、允许失败，尚无正式 Release |
| Android | ⏳ 构建中 | 上游 Android 构建链保留，尚未发布 NEILICO 包 |

状态以当前仓库和 Release 为准；“构建中”不等于已发布或已验收。

## 怎么下载

Windows 可从 [v1.5.0-neilico.1 Release](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) 下载当前资产 `neilico-windows-x64.zip`，也可以从你自己的 NEILICO 控制面下载固定命名的客户端包：

```text
https://<SERVER>/downloads/neilico-client-windows-x64.zip
```

控制面下载目录由 `NEILICO_DOWNLOADS_DIR` 指定；文件名必须符合下载白名单。Release 资产当前叫 `neilico-windows-x64.zip`，控制面包名是 `neilico-client-windows-x64.zip`，复制到下载目录时请按后者命名。

## 怎么构建

工具链固定为 **Flutter 3.24.5**、**Rust 1.75**；Windows CI 位于 [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml)，并使用 windows-2022、LLVM 15.0.6、vcpkg 和 RustDesk 自定义 Flutter engine。CI 会先生成 `flutter-rust-bridge` 文件，再编译 Rust 核心和 Flutter 应用。

核心构建命令为：

```bash
cargo build --locked --release --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

`hwcodec`/`vram` 需要对应平台的编解码与 vcpkg 依赖。Linux/macOS/Android 的完整前置依赖和产物布局不同，请以各自 workflow 为准；当前 CI 尚未把它们作为发布验收目标。

## 怎么注入服务器

构建前注入 hbbs 地址和服务端公钥：

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --locked --release --features "flutter,hwcodec,vram"
```

CI 从仓库变量 `vars.NEILICO_ID_SERVER` 和密钥 `secrets.NEILICO_PUB_KEY` 注入。**未注入时不会连接任何服务器**：源码使用占位符 `your-server.example.com` 与 `YOUR_HBBS_PUBLIC_KEY`，必须替换为自建 hbbs/hbbr 的真实地址和 `id_ed25519.pub` 公钥后重新构建。不要把私钥提交进仓库或写入客户端。

## 仪表盘 / 管理端

`app/` 是我们的 Flutter 设备与策略管理端，负责设备列表、接入状态、远程控制策略、隧道模式和 Mesh 策略管理；`rust-core/` 是内核接入骨架。迁移来源是主仓库 commit `88e0b974b20c927bc3d98798078217c01c60c692`，使用 `git subtree` 保留来源提交历史。管理端不代替远程桌面客户端，也不提供连接按钮或连接入口。所有连接均由 NEILICO 客户端自己发起，Web 只做管理。

## AGPL-3.0 合规

这是 `rustdesk/rustdesk` 1.5.0 的修改版，上游和本修改版均适用 **GNU Affero General Public License v3.0**：

- 保留 [`LICENCE`](LICENCE) 原文；另提供内容相同的 [`LICENSE`](LICENSE)，便于 GitHub 识别许可。
- 保留 [`NOTICE`](NOTICE)，记录上游 tag `1.5.0`、上游 commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`、我方改动和 Corresponding Source 地址。
- 对应源码地址：[github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client)。
- 原上游版权、许可文本和署名未删除；修改内容及来源见 `NOTICE`。

---

# English

NEILICO Client is the official multi-platform remote-desktop client for Windows, Linux, macOS, and Android. It is a modified version of `rustdesk/rustdesk` 1.5.0 and is distributed under **AGPL-3.0**. This repository also includes the Flutter device/policy management app migrated from the server repository under `app/`, plus the `rust-core/` integration skeleton.

## Platform status

| Platform | Status | Delivery |
| :-- | :-- | :-- |
| Windows x64 | ✅ Released | [Release v1.5.0-neilico.1](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) |
| Linux x64 | ⏳ Building | Manual CI in `.github/workflows/neilico-build.yml`, allowed to fail; no release yet |
| macOS | ⏳ Building | Manual CI in `.github/workflows/neilico-build.yml`, allowed to fail; no release yet |
| Android | ⏳ Building | Upstream Android toolchain retained; no NEILICO package released yet |

“Building” does not mean released or accepted.

## Download

Windows users can download the current Release asset `neilico-windows-x64.zip`, or use their own control plane at `/downloads/neilico-client-windows-x64.zip`. The release asset and control-plane filename are intentionally different; use the latter filename when placing the package in `NEILICO_DOWNLOADS_DIR`.

## Build

Use **Flutter 3.24.5** and **Rust 1.75**. The Windows workflow is [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml). The core commands are:

```bash
cargo build --locked --release --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

The workflow generates the `flutter-rust-bridge` files first and handles Windows-specific engine and dependency setup. Other platforms have different prerequisites and are not release acceptance targets yet.

## Inject the server

Set the build-time environment variables before compiling:

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --locked --release --features "flutter,hwcodec,vram"
```

CI injects `vars.NEILICO_ID_SERVER` and `secrets.NEILICO_PUB_KEY`. If they are omitted, the build contains the placeholders `your-server.example.com` and `YOUR_HBBS_PUBLIC_KEY` and **cannot connect to any server**. Replace them with your hbbs/hbbr address and `id_ed25519.pub` public key and rebuild. Never commit or embed the private key.

## Dashboard / management app

`app/` is our Flutter device and policy management app. It manages device status, remote-control policy, tunnel mode, and Mesh policy. `rust-core/` is the kernel integration skeleton. The migration source is server-repository commit `88e0b974b20c927bc3d98798078217c01c60c692`; `git subtree` preserves that source history. The management app is not a remote-desktop client and exposes no connection entry point; every connection is initiated by the NEILICO client itself.

## AGPL-3.0 compliance

This is a modified version of `rustdesk/rustdesk` 1.5.0 and is subject to the **GNU Affero General Public License v3.0**. Keep [`LICENCE`](LICENCE) unchanged and use the identical [`LICENSE`](LICENSE) copy for GitHub license detection. [`NOTICE`](NOTICE) records upstream tag `1.5.0`, upstream commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`, our modifications, and the Corresponding Source URL: [github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client). Upstream copyright, license text, and attribution remain intact.
