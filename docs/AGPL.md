# AGPL-3.0 compliance / AGPL-3.0 合规说明

[English README](../README.md) | [简体中文 README](../README.zh-CN.md)

NEILICO Client is a modified version of `rustdesk/rustdesk` 1.5.0 and is distributed under the GNU Affero General Public License v3.0.

NEILICO Client 是 `rustdesk/rustdesk` 1.5.0 的修改版，适用 GNU Affero General Public License v3.0。

## Required files / 必备文件

| File / 文件 | Purpose / 用途 |
| :-- | :-- |
| [`../LICENCE`](../LICENCE) | Verbatim upstream AGPL-3.0 license text. / 原样保留的上游 AGPL-3.0 许可原文。 |
| [`../LICENSE`](../LICENSE) | Identical license copy provided for GitHub license detection. / 内容相同的许可副本，便于 GitHub 识别许可。 |
| [`../NOTICE`](../NOTICE) | Upstream provenance, modification notice, and Corresponding Source location. / 上游来源、修改说明和 Corresponding Source 地址。 |

## Upstream provenance / 上游来源

**English:** The source is based on upstream tag `1.5.0` at commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`. The bundled `libs/hbb_common` origin is recorded in `NOTICE`. Original copyright notices and license text remain intact.

**简体中文：** 源码基于上游 tag `1.5.0`、commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`。随附 `libs/hbb_common` 的来源记录在 `NOTICE` 中。原版权通知和许可文本均保持不变。

## Modifications / 修改

**English:** `NOTICE` records the rebranding, build-time server/public-key injection, icon changes, and About-page source/modification notice. The modification summary is informational; `NOTICE` is the maintained compliance record.

**简体中文：** `NOTICE` 记录品牌替换、构建期服务器/公钥注入、图标修改以及 About 页的源码和修改提示。上述摘要用于快速理解；持续维护的合规记录以 `NOTICE` 为准。

## Corresponding Source / 对应源码

**English:** The Corresponding Source location is [github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client). Users who interact with the program over a network must be offered access to the Corresponding Source under AGPL-3.0. This repository is the maintained source location.

**简体中文：** Corresponding Source 地址为 [github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client)。按照 AGPL-3.0，通过网络与程序交互的用户必须能够获得 Corresponding Source；本仓库是持续维护的源码地址。

## Secrets / 密钥边界

**English:** `NEILICO_PUB_KEY` is the RustDesk server public key used at build time. The RustDesk private key is not part of this repository or client distribution and must never be embedded in either.

**简体中文：** `NEILICO_PUB_KEY` 是构建期使用的 RustDesk 服务端公钥。RustDesk 私钥不属于本仓库或客户端分发内容，绝不能嵌入其中。
