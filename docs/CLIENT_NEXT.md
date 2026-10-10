# NEILICO 客户端下一阶段设计（S0 + S1）

> 本文是实现结论，不列开放选项。S1 的实现边界以本文为准；S2 仅在本文接口位上继续演进。

## 1. 总体架构

NEILICO 仍是一个客户端应用，但“一个 App”不等于“一个操作系统进程”。最终形态由三类进程组成：

1. **主 UI 进程**（`neilico`）：Flutter 设置页、远程桌面主控端会话入口、能力开关和本地状态。
2. **Mesh agent 子进程**（`neilico-agent`）：仅在 `Mesh 网络` 打开时存在，复用主仓库 `agent/` 的已验证 Go 实现，负责接入、心跳、配置拉取、WireGuard/VIP/路由和漂移处理。
3. **远程桌面服务子进程**（`neilico --neilico-remote-desktop`）：仅在 `远程桌面` 打开时存在，进入既有 RustDesk 被控端内核。

这样划界的直接收益是“关闭即释放”：关闭能力时结束对应子进程，操作系统回收其端口、线程、GPU/采集句柄和堆内存；UI 开关不会只做视觉隐藏。

### 与控制面的职责边界

| 职责 | 控制面 | 客户端 |
| --- | --- | --- |
| NEILICO ID/设备身份 | 签发、绑定、确认、吊销 | 保存短期凭据并调用接口 |
| Mesh 节点身份 | enrollment、agent token、VIP、peer、AllowedIPs | agent 生命周期、接入配置输入 |
| Mesh 网络配置 | 下发 WireGuard 配置、路由、漂移基准 | 应用、探测、清理本地网络状态 |
| 策略 | 记录 `deny`/`allow`，其中 `deny` 为硬策略 | `deny` 不可覆盖并立即停能力；`allow` 只解除禁止，用户仍可关闭 |
| 远程桌面能力 | 后续确认设备绑定后才允许建立连接 | 运行时开关、被控端服务生命周期 |
| 升级 | 发布版本、校验和、回滚策略（S2） | 下载、校验、替换（S2） |

控制面可以**禁止**某能力，但不能把“允许”解释成“强制开启”。用户始终拥有关闭权。

## 2. Mesh 落地路线

### 方案比较

| 维度 | A：内嵌已验证 Go agent 子进程 | B：Rust 原生实现 |
| --- | --- | --- |
| 复用 | 直接复用 `agent/` 的注册、心跳、配置、WireGuard、VIP、路由和漂移检测 | 需重写并重新验证全部协议与漂移逻辑 |
| 关闭成本 | 结束 PID 后资源由 OS 回收，`ps` 和 `ip link` 可直接验收 | Rust 静态库仍留在 UI 进程，必须自行拆除线程/端口/捕获器 |
| 工作量 | 小；主要工作是打包、进程管理和策略门控 | 大；至少跨控制面 API、WireGuard、平台权限和漂移恢复 |
| 资源 | 多一个进程和一份独立二进制，但占用边界清晰 | 单进程，关闭后若清理不完整会残留内存 |
| 风险 | agent 二进制/Go 版本/权限模型需随包管理；Windows 的网络命令适配要单独验证 | 协议兼容、漂移恢复和安全审计风险高，容易把 S1 扩成平台项目 |

### 结论

**本轮选择方案 A：先内嵌 Go agent 子进程，方案 B 作为 S2 后续演进。**

理由：需求的核心是“关闭即真实释放”，子进程边界可以在本轮用 `ps`/`ip link` 直接证明；而 Rust 原生方案会把已验证的 Mesh 控制面协议、WireGuard 生命周期和漂移检测重新引入到远程桌面客户端中，工作量和回归面都远大于 S1。方案 B 仅在以下条件同时满足后启动：agent 的跨平台权限模型稳定、控制面 API 冻结、已有真实部署的漂移恢复指标、并有明确的单进程内存收益。

方案 A 的已知风险：内嵌二进制增加发行包大小；agent 需要管理员/`CAP_NET_ADMIN` 才能真正建网卡；Windows 发行包中的 agent 已编译但本轮未在 Windows 真机建网卡验证；Mesh agent 的上游根许可证仍需在公开发布前改成明确许可证。

## 3. 远程桌面“关”的精确定义

`远程桌面` 关闭时，NEILICO 不启动、也不保留以下运行时资源：

| 资源 | 文件/函数 | 关闭后的结果 |
| --- | --- | --- |
| ID 注册、续约、NAT/打洞 | `src/rendezvous_mediator.rs::RendezvousMediator::start_all`、`start_udp`、`start_tcp` | 不进入该函数；既有服务子进程被终止 |
| 直连监听、LAN 发现 | `src/rendezvous_mediator.rs::direct_server`、`src/lan.rs::start_listening` | 不绑定 UDP/TCP/发现端口 |
| 服务入口/IPC 监听 | `src/server.rs::start_server`、`crate::ipc::start` | `--neilico-remote-desktop` 子进程不生成 |
| 屏幕采集 | `src/server/video_service.rs::create_capturer`、`get_capturer`，底层 `libs/scrap/` | 不创建 DXGI/GDI/DRM/PipeWire capturer |
| 音频服务 | `src/server/audio_service.rs` 及 `src/server/connection.rs` 的 audio service 订阅 | 不启动音频采集/播放服务 |
| 输入服务 | `src/server/input_service.rs`、`src/server/uinput.rs`、`src/server/rdp_input.rs` | 不创建输入 hook/uinput |
| 文件传输、剪贴板、终端、远程打印 | `src/server/connection.rs`、`src/server/clipboard_service.rs`、`src/server/terminal_service.rs`、`src/server/printer_service.rs` | 不接受相应服务消息 |
| 主控端远程会话 | `src/flutter_ffi.rs::session_add_sync`、`session_add_existed_sync` | 在 `ensure_remote_desktop_enabled()` 处拒绝，不创建 `FlutterSession` |

实现上，`src/core_main.rs` 的冷启动只调用 `src/neilico/remote_desktop.rs::start_if_enabled()`；它在默认值（缺失或非 `Y`）下立即返回。开关开启后才 spawn `neilico --neilico-remote-desktop`，该子进程才进入 `src/server.rs::start_server(true, false)`。关闭时对子进程发 SIGTERM、等待其退出，再由操作系统回收监听句柄、采集器和内存。Linux 系统服务的 `src/platform/linux.rs::should_start_server` 同样在能力关闭时停止/不启动 `--server`。

因此，“关闭”是进程生命周期门控，不是 UI 隐藏：`ps` 不应再有 `neilico-agent` 或 `--neilico-remote-desktop`，`ip link` 不应再有 `wg0`，远程桌面的网络监听也不应存在。

## 4. 内存目标与测法

### 测法

* 平台：同一 Linux x86_64 会话，同一构建，冷启动后等待 **60 秒**再取样。
* 主进程用 `ps -o rss=,vsz= -p <pid>`；能力子进程单独取样，并给出 RSS 合计。
* 四种状态各采样一次：**都关 / 只开 Mesh / 只开 RD / 都开**。每种状态至少做一次“开→关”回归，并在关闭后重复 `ps`/`ip link`。
* 数字是运行时 RSS/VSZ（KiB），不是磁盘产物大小；Windows CI 只证明构建，不冒充 Windows 真机内存。

### 目标

本轮“都关”冷启动 60 秒实测基线 `B = 205,364 KiB RSS（200.6 MiB）`。据此定下数值目标：

* **远程桌面关**：不存在客户端管理的 `--neilico-remote-desktop` 进程；其他能力关闭时，进程 RSS 合计 **< 225 MiB**。
* **Mesh 关**：不存在客户端管理的 `neilico-agent` 进程；其他能力关闭时，进程 RSS 合计 **< 225 MiB**。
* **都关**：RSS 合计 **< 225 MiB**；一次开关循环后允许回落带宽为基线 +12%，用来吸收页面/配置缓存，但不允许保留能力子进程。
* **能力开启**的增量作为观测项，不把子进程堆内存算成可接受的“隐藏成本”。

### S1 四态实测（Linux x86_64，2026-10-10）

命令均为 `ps -o rss=,vsz= -p <pid>`，单位 KiB；合计列只加 RSS。

| 状态 | 进程 | RSS | VSZ | RSS 合计 |
| --- | --- | ---: | ---: | ---: |
| 都关 | UI `neilico` | 205,364 | 4,141,608 | **205,364（200.6 MiB）** |
| 只开 Mesh | UI `neilico` | 209,988 | 4,144,164 | **228,940（223.6 MiB）** |
| 只开 Mesh | `neilico-agent` | 18,952 | 1,273,620 |  |
| 只开 RD | UI `neilico` | 206,840 | 4,135,828 | **259,268（253.2 MiB）** |
| 只开 RD | `--neilico-remote-desktop` | 52,428 | 2,478,068 |  |
| 都开 | UI `neilico` | 212,388 | 4,141,460 | **284,252（277.6 MiB）** |
| 都开 | `--neilico-remote-desktop` | 52,456 | 2,478,068 |  |
| 都开 | `neilico-agent` | 19,408 | 1,273,884 |  |
| 都关（开关循环后） | UI `neilico` | 214,096 | 4,142,772 | **214,096（209.1 MiB）** |

四态均超过 60 秒稳定窗口取样；“开关循环后”低于 225 MiB 目标，且两个能力子进程均已退出。Mesh 的内存态使用本地 mock 控制面保持 agent 在线；真实建网卡/清网卡另在隔离网络命名空间验收。

## 5. 开关与控制面策略

策略模型只保留两个动作：

* `deny`：写入 `HARD_SETTINGS` 的 `neilico-forbid-mesh` / `neilico-forbid-remote-desktop`，客户端在 `set_enabled`、服务入口和会话入口都拒绝覆盖；UI 显示“由控制面策略强制禁止”。
* `allow`：删除对应禁止记录，**不**自动打开能力；用户仍可在设置页关闭。

`src/flutter_ffi.rs::main_apply_neilico_control_policy` 是后续控制面下发的接口位。它和现有 `OVERWRITE_SETTINGS` 分离，避免把“允许”误当成“强制开启”。开关值使用 `Y`/`N` 显式判断，缺失值冷启动按关闭处理，满足“安装即最省”。

## 6. NEILICO ID 预留

S1 只预留接口，不做设备绑定：

1. `main_apply_neilico_control_policy(policy_json)`：接收控制面策略 JSON，可扩展 `mesh`、`remote_desktop`。
2. `session_add_sync` / `session_add_existed_sync` 的统一入口：S2 在这里插入“控制面确认设备绑定后才允许连接”的查询。
3. Mesh 的 `--state-dir`/`NEILICO_TOKEN` 传参保留给后续“NEILICO ID ↔ 设备绑定”结果；绑定结果不应写入仓库配置文件，只保存在用户配置目录。

## 7. S1 验收记录

* 设置页：`Mesh 网络`、`远程桌面` 开关，开关下实时状态：运行中 / 已停止 / 已关闭 / 由控制面策略强制禁止。
* Mesh 设置：控制面地址、接入令牌、可选连接串；开启拉起 `neilico-agent`，关闭终止并清理 `wg0`。
* 冷启动：两能力默认关闭。
* 硬策略：`deny` 不可覆盖，`allow` 不会强制开启。
* 设置控件截图：`docs/evidence/neilico-capabilities-settings.png`。

### 关闭清理实测

客户端管理的 Mesh PID `1890548` 在关闭前后分别执行 `ps -o pid=,rss=,vsz=,cmd= -p 1890548`：关闭前有输出，关闭后无输出。隔离网络命名空间内的 `ip link show`：

```text
--- before close ---
4: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 ...
--- after close ---
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
```

即同一网络命名空间中先出现 `wg0`，SIGTERM 后 `wg0` 消失。宿主全局 `ip link show` 当前另有一个由 系统级 root agent 管理的既有 `wg0`，不属于客户端子进程，未被本任务创建或删除。

关闭后客户端管理路径扫描：

```text
managed neilico-agent: 0
managed --neilico-remote-desktop: 0
```

宿主全局 `ps aux | grep neilico-agent` 会命中上述既有 root agent，并会因 Codex 命令文本包含关键词而命中当前 shell；因此验收以可执行路径/PID 管理关系为准，并如实保留这一宿主环境例外。

### 设置截图说明

本机 Linux 会话中的标准 Flutter 引擎在 Xvfb 与 Wayland 都把应用窗口呈现为黑屏（上游 Linux 包装尚未验证，属 S2 范围）。为不伪造运行时截图，证据图是使用同一控件结构的 Flutter 离屏渲染；它能验收两个开关、状态文案和 Mesh 配置字段的布局，但不能替代 Windows 真机窗口截图。
