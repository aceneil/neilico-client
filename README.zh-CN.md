[English](README.md) | **简体中文**

# NEILICO Client

NEILICO Client 是 NEILICO 的官方远程桌面客户端。它基于 `rustdesk/rustdesk` 1.5.0 修改，整体适用 **AGPL-3.0**。仓库同时包含从服务端仓库迁入的 Flutter 设备与策略管理端（`app/`）和 `rust-core/` 内核接入骨架。

## 平台状态

| 平台 | 状态 | 当前交付 |
| :-- | :-- | :-- |
| Windows x64 | ✅ 已出包 | [Release v1.5.0-neilico.1](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) |
| Linux x64 | ⏳ 待发布 | [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml) 有手动 CI，但允许失败且尚无 Release 包 |
| macOS | ⏳ 待发布 | [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml) 有手动 CI，但允许失败且尚无 Release 包 |
| Android | ⏳ 待发布 | 上游 Android 工具链仍保留在仓库中，但尚未发布 NEILICO 包 |

状态以当前仓库和 GitHub Release 为准；「待发布」不等于已经发布或已经验收。

## 怎么下载

Windows 可从 [v1.5.0-neilico.1 Release](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) 下载当前包。也可以从你自己的 NEILICO 控制面分发：

```text
https://<SERVER>/downloads/neilico-client-windows-x64.zip
```

控制面下载目录由 `NEILICO_DOWNLOADS_DIR` 指定，文件名必须符合下载白名单。当前 Release 资产名为 `neilico-windows-x64.zip`，控制面包名必须是 `neilico-client-windows-x64.zip`；放进下载目录时请按后者重命名。

## 怎么构建

工具链固定为 **Flutter 3.24.5** 和 **Rust 1.75**。Windows 核心构建命令为：

```bash
cargo build --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

`hwcodec`/`vram` 需要对应的编解码和 vcpkg 依赖。Linux、macOS、Android 的前置条件和产物布局不同，当前也不是发布验收目标。详细前置依赖、CI 位置和构建说明见 [`docs/BUILD.md`](docs/BUILD.md)。

## 怎么注入服务器

构建前注入 hbbs 地址和服务端公钥：

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --features "flutter,hwcodec,vram"
```

CI 从 `vars.NEILICO_ID_SERVER` 和 `secrets.NEILICO_PUB_KEY` 读取。**未注入时，构建产物只包含占位符 `your-server.example.com` 和 `YOUR_HBBS_PUBLIC_KEY`，连不上任何服务器。** 必须替换为你自己的 hbbs/hbbr 地址和 `id_ed25519.pub` 公钥后重新构建。不要提交或嵌入私钥。

## Flutter 管理端

[`app/`](app/) 是我们的 Flutter 设备与策略管理端，负责设备列表、接入状态、远程控制策略、隧道模式和 Mesh 策略管理。`rust-core/` 是内核接入骨架。迁移来源是服务端仓库 commit `88e0b974b20c927bc3d98798078217c01c60c692`，使用 `git subtree` 保留来源提交历史。

管理端不是远程桌面客户端，也不提供连接按钮或连接入口。**所有连接一律由 NEILICO 客户端自身发起，Web 只做管理。**

## AGPL-3.0 合规

这是 `rustdesk/rustdesk` 1.5.0 的修改版，适用 **GNU Affero General Public License v3.0**：

- 原样保留上游 [`LICENCE`](LICENCE)；另提供内容相同的 [`LICENSE`](LICENSE)，便于 GitHub 识别许可。
- 保留 [`NOTICE`](NOTICE)，记录上游 tag `1.5.0`、上游 commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`、我方改动和 Corresponding Source 地址。
- 对应源码地址：[github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client)。
- 上游版权、许可文本和署名均未删除。详细说明见 [`docs/AGPL.md`](docs/AGPL.md)。

## 文档

双语 [`docs/README.md`](docs/README.md) 索引项目指南和全部上游文档译本。构建与许可长文见 [`docs/BUILD.md`](docs/BUILD.md) 和 [`docs/AGPL.md`](docs/AGPL.md)。
