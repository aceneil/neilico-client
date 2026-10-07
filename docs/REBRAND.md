# NEILICO 客户端改造点（REBRAND）

把 **rustdesk/rustdesk** 上游源码改造成 **NEILICO** 自建客户端：改名、改图标、
把默认 ID/中继服务器与公钥换成我们自建的 `hbbs`/`hbbr`，并记录跨平台构建与 AGPL 合规。

> 所有行号均为**本轮改造后**的仓库行号。上游主干变动后需重校。

---

## 1. 上游基线（固定 tag，不追 master）

| 项 | 值 |
| :-- | :-- |
| 上游仓库 | https://github.com/rustdesk/rustdesk |
| 采用 tag | **1.5.0** |
| **commit** | **`fada664df7a294d1d1a9ca3e7cd3637069122f17`** |
| 子模块 `libs/hbb_common` | https://github.com/rustdesk/hbb_common @ `229b904508364c8997aad0fb5af57effac859f60` |
| 许可证 | AGPL-3.0（仓库根 `LICENCE`，**原样保留**） |
| 本地路径 | `$HOME/Documents/Projects/rustdesk-fork` |
| 仓库体积 | ~28 MB（含 `.git` 7.4 MB；`--depth 1` 浅克隆 + 子模块） |

```bash
git clone --depth 1 --branch 1.5.0 https://github.com/rustdesk/rustdesk.git rustdesk-fork
cd rustdesk-fork
git submodule update --init libs/hbb_common   # 必须！服务器/公钥/应用名常量都在这个子模块里
```

> ⚠️ `libs/hbb_common` 是 **git 子模块**。普通 clone 后该目录为空，
> `RS_PUB_KEY` / `RENDEZVOUS_SERVERS` / `APP_NAME` 都读不到。见 §7 残留 #5。

---

## 2. 改造点清单（精确到 文件:行号）

### 2.1 默认 ID 服务器 / 中继服务器 / 公钥 ★核心

文件：**`libs/hbb_common/src/config.rs`**（已核实，常量定义就在此文件顶部常量区）

| 行号 | 常量 | 上游值 | 我们的值 |
| :-- | :-- | :-- | :-- |
| **57** | `ORG`（`cfg(macos)`） | `"com.carriez"` | `"local.neilico"` |
| **121** | `NEILICO_ID_SERVER`（**新增**） | — | `match option_env!("NEILICO_ID_SERVER") { Some(v)=>v, None=>"192.168.1.10" }` |
| **125** | `RENDEZVOUS_SERVERS`（默认 ID 服务器） | `["rs-ny.rustdesk.com"]` | `[NEILICO_ID_SERVER]` |
| **126** | `RS_PUB_KEY`（默认公钥） | `"OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw="` | `match option_env!("NEILICO_PUB_KEY") { Some(v)=>v, None=>"YOUR_HBBS_PUBLIC_KEY" }` |

（中继端口常量同文件：`RENDEZVOUS_PORT=21116`(:131)、`RELAY_PORT=21117`(:132)、`WS_*=21118/21119`(:133-134)，端口与上游一致，未改。）

**运行期调用链（已核实，非臆测）**：

* `Config::get_rendezvous_server()`（`config.rs:921` 起）取值顺序：
  `EXE_RENDEZVOUS_SERVER` → 用户设置 `custom-rendezvous-server` → `PROD_RENDEZVOUS_SERVER`
  → `CONFIG2.rendezvous_server` → **`RENDEZVOUS_SERVERS[0]`（我们改的常量）**，末尾自动补 `:21116`。
  → 全新安装、未填自定义服务器时，客户端直接用我们的 hbbs。
* 公钥：`Config::get_key()`（`src/common.rs:2019` 起）在用户未填 `key` 时回落到 `config::RS_PUB_KEY`；
  `src/client.rs:1650 secure_connection()` 也用它作默认校验键。→ 我们的公钥即"默认 Key"。
* 服务器列表另一处引用：`config.rs:968`（`get_rendezvous_servers()` 也返回 `RENDEZVOUS_SERVERS`）。
* 中继：本机 hbbs 未带 `-r`，客户端自动推导中继 = 同机 `:21117`。

**生产环境改成公网域名（可构建期注入，无需改源码）**：

```bash
NEILICO_ID_SERVER=rd.example.com \
NEILICO_PUB_KEY=YOUR_HBBS_PUBLIC_KEY \
  cargo build --locked --lib --features flutter --release
```

> 本轮为**验证真能连上我们自己的 hbbs**，默认值取本机 hbbs 的局域网地址 `192.168.1.10`
> （可用 `NEILICO_ID_SERVER` 覆盖）。发行前请换公网域名后重编。

### 2.2 应用名 / 包标识（appid）/ 版本号 —— 分平台

**通用（Rust，所有平台）**

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `libs/hbb_common/src/config.rs:72` | `APP_NAME`（**唯一产品名来源**） | `"RustDesk"` | `option_env!("NEILICO_APP_NAME").unwrap_or("NEILICO")` |
| `libs/hbb_common/src/config.rs:57` | `ORG`（macOS 前缀） | `"com.carriez"` | `"local.neilico"` |
| `Cargo.toml:3` | 版本基线 | `1.5.0` | `1.5.0`（未改） |
| `libs/hbb_common/src/lib.rs:228` | `gen_version()` 构建期生成 `src/version.rs` | — | 未改逻辑（`build.rs:main()` 调用） |

> `APP_NAME` 是**唯一**产品名来源：`src/common.rs:1082 get_app_name()`、
> `src/flutter_ffi.rs:1120 main_get_app_name()`、托盘/自启动/URI scheme（`src/common.rs:1093`）都读它。
> **附带效果**：`src/lang.rs:258` 在非官方名时，把 UI 文案里的 `"RustDesk"` 自动替换成 `APP_NAME`
> —— 所以「关于 RustDesk」等翻译键在界面自动显示为 **NEILICO**，无需逐个改语言文件。

**Linux**（`flutter/linux/`）

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `flutter/linux/CMakeLists.txt:7` | 可执行名 `BINARY_NAME` | `rustdesk` | `neilico` |
| `flutter/linux/CMakeLists.txt:10` | GTK appid `APPLICATION_ID` | `com.carriez.flutter_hbb` | `local.neilico.neilico` |
| `flutter/linux/my_application.cc:119` | 窗口图标名（GTK 主题查找） | `"rustdesk"` | `"neilico"` |
| `flutter/linux/my_application.cc:145` | 顶部标题栏文字 | `"rustdesk"` | `"NEILICO"` |
| `flutter/linux/my_application.cc:149` | 窗口标题 | `"rustdesk"` | `"NEILICO"` |

**Android**（`flutter/android/`）

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `flutter/android/app/build.gradle:102` | `applicationId`（用户可见包名） | `com.carriez.flutter_hbb` | `local.neilico.neilico` |
| `flutter/android/app/build.gradle:85` | `namespace` | `com.carriez.flutter_hbb` | **保持**（= `AndroidManifest.xml:4` 的 `package`；改它要连带搬 15 个 kotlin 包目录，见 §7#2） |
| `flutter/android/app/src/main/AndroidManifest.xml:32` | `android:label`（桌面名） | `RustDesk` | `NEILICO` |
| `.../AndroidManifest.xml:52` | 无障碍服务名 | `RustDesk Input` | `NEILICO Input` |

**iOS**（`flutter/ios/`）

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `flutter/ios/Runner.xcodeproj/project.pbxproj:437,633,721` | `PRODUCT_BUNDLE_IDENTIFIER` | `com.carriez.flutterHbb` | `local.neilico.neilico` |
| `flutter/ios/Runner/Info.plist:9-10` | `CFBundleDisplayName` | `RustDesk` | `NEILICO` |
| `flutter/ios/Runner/Info.plist:17-18` | `CFBundleName` | `RustDesk` | `NEILICO` |
| `flutter/ios/Runner/Info.plist:35,38` | URL scheme id / scheme | `com.carriez.rustdesk` / `rustdesk` | `local.neilico.neilico` / `neilico` |

**macOS**（`flutter/macos/`）

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `flutter/macos/Runner/Configs/AppInfo.xcconfig:8` | `PRODUCT_NAME`（窗口标题） | `RustDesk` | `NEILICO` |
| `flutter/macos/Runner/Configs/AppInfo.xcconfig:11` | `PRODUCT_BUNDLE_IDENTIFIER` | `com.carriez.flutterHbb` | `local.neilico.neilico` |
| `flutter/macos/Runner/Configs/AppInfo.xcconfig:14` | `PRODUCT_COPYRIGHT` | Purslane only | NEILICO + 保留 Purslane |
| `flutter/macos/Runner.xcodeproj/project.pbxproj:448,593,630` | `PRODUCT_BUNDLE_IDENTIFIER` | `com.carriez.rustdesk` | `local.neilico.neilico` |
| `flutter/macos/Runner/Info.plist:29,32` | URL name / scheme | `com.carriez.rustdesk` / `rustdesk` | `local.neilico.neilico` / `neilico` |

**Windows**（`flutter/windows/`）

| 文件:行号 | 项 | 上游 | 现在 |
| :-- | :-- | :-- | :-- |
| `flutter/windows/CMakeLists.txt:7` | 可执行名 `BINARY_NAME` | `rustdesk` | `neilico` |
| `flutter/windows/runner/Runner.rc:92` | `CompanyName` | Purslane | `NEILICO` |
| `flutter/windows/runner/Runner.rc:93` | `FileDescription` | `RustDesk Remote Desktop` | `NEILICO Remote Desktop` |
| `flutter/windows/runner/Runner.rc:95` | `InternalName` | `rustdesk` | `neilico` |
| `flutter/windows/runner/Runner.rc:96` | `LegalCopyright` | Purslane only | NEILICO + 保留 Purslane |
| `flutter/windows/runner/Runner.rc:97` | `OriginalFilename` | `rustdesk.exe` | `neilico.exe` |
| `flutter/windows/runner/Runner.rc:98` | `ProductName` | `RustDesk` | `NEILICO` |

**Flutter 公共**

| 文件:行号 | 项 | 说明 |
| :-- | :-- | :-- |
| `flutter/pubspec.yaml:1` | Dart 包名 `flutter_hbb` | **保持**（91 个文件 `import 'package:flutter_hbb/...'`，改名=大规模重构，非用户可见） |
| `flutter/pubspec.yaml:2` | `description` | `Your Remote Desktop Software` → `NEILICO Remote Desktop` |
| `flutter/pubspec.yaml:19` | `version` | `1.5.0+68`（未改；iOS 版本约束特殊，见文件注释） |
| `flutter/pubspec.yaml:133-143` | `flutter_icons:` 段 | 图标来源：`image_path: ../res/icon.png`、`macos: ../res/mac-icon.png`、`linux: true` |

> **绝对不要改名**：Rust 库名 `[lib] name = "librustdesk"`（`Cargo.toml:12`）→ 产出的
> `librustdesk.so/.dll` 被 `flutter/lib/models/native_model.dart:34`、
> `flutter/linux/main.cc:59`、`flutter/windows/runner/main.cpp:26` 按名加载。Dart 包名同理。

### 2.3 图标 —— 分平台

上游图标源在 `res/` 与各平台 `Assets/`。本轮统一用 NEILICO 品牌图
（源：`neilico/desktop/macos/.../app_icon_1024.png`）重新生成：

| 平台 | 文件 | 处理 |
| :-- | :-- | :-- |
| 通用 | `res/icon.png`、`res/mac-icon.png`（1024²）、`res/128x128.png`、`res/128x128@2x.png`(256)、`res/32x32.png`、`res/64x64.png`、`res/icon.ico`、`res/tray-icon.ico` | 全部换成 NEILICO 图 |
| Linux | `flutter/assets/icon.png`（**新增**） | 应用内 logo；`flutter/lib/common.dart:3825 loadIcon()` 优先读它 |
| Android | `flutter/android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`、`ic_launcher_round.png`、`ic_launcher_foreground.png` | 按 48/72/96/144/192（前两者）与 108/162/216/324/432（foreground）重生成 |
| iOS | `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`（15 个） | 按文件名尺寸重生成，去 alpha 压白底 |
| Windows | `flutter/windows/runner/resources/app_icon.ico` | 换成 NEILICO 多尺寸 ICO |
| macOS | 走 `flutter_icons` 的 `macos: ../res/mac-icon.png`（无独立 appiconset） | 由 `res/mac-icon.png` 驱动 |

### 2.4 桌面集成（Linux 打包用）

| 文件 | 改动 |
| :-- | :-- |
| `res/rustdesk.desktop` | `Name=NEILICO`、`Exec=neilico %u`、`Icon=neilico`、`StartupWMClass=neilico` |
| `res/rustdesk-link.desktop` | 同上 + `MimeType=x-scheme-handler/neilico;`（配合新深链 `neilico://`） |
| `res/rustdesk.service` | `Description=NEILICO`、`ExecStart=/usr/bin/neilico --service`、`PIDFile=/run/neilico.pid` |

> 文件名仍是 `rustdesk.*`（`build.py` 按此名打包），内容已改；改文件名属下一轮（§7#1）。

### 2.5 关于页（AGPL §13 源码地址）

文件：`flutter/lib/desktop/pages/desktop_setting_page.dart`

| 行号 | 改动 |
| :-- | :-- |
| `2535` | 标题 `translate('About RustDesk')` → 经 §2.2 语言替换后界面显示 **About NEILICO** |
| `2579` | **新增**链接行：`Source code (NEILICO, AGPL-3.0)` → `https://github.com/aceneil/neilico-client` |
| `2600` | **新增**页脚声明：`NEILICO is a modified fork of RustDesk, licensed under AGPL-3.0.` + 源码地址 |
| `2583` | 上游版权行 `Copyright © … Purslane Tech Pte. Ltd.` **原样保留**（未删改） |

---

## 3. 构建入口与最短路径

### 3.1 上游入口

| 入口 | 位置 | 说明 |
| :-- | :-- | :-- |
| 主编排 | `build.py` | `get_version()`(:58)、`get_features()`(:315)、`build_flutter_deb()`(:737) |
| Linux 打包核心 3 步 | `build.py:737-742` | `cargo build --locked --features {features} --lib --release` → `flutter build linux --release` |
| CI | `.github/workflows/bridge.yml`（桥接）+ `flutter-build.yml`（三平台矩阵，Linux job 起 `:1514`，核心编译 `:1723`） | |

### 3.2 只编 Linux 的**最短路径**（不碰 Android/iOS/Windows 依赖）

```bash
# 阶段 0：一次性生成 flutter↔rust 桥接代码（frb 1.80.1，同上游 bridge.yml）
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --locked
cargo install cargo-expand --version 1.0.95 --locked
rustup component add rustfmt
flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs \
    --dart-output ./flutter/lib/generated_bridge.dart \
    --c-output ./flutter/macos/Runner/bridge_generated.h
cp ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h
# 上游 build.py:ffi_bindgen_function_refactor 的 ffigen workaround：
#   generated_bridge.dart 里把 ffi.Bool Function(DartPort port_id, ...) 改成 ffi.Uint8 ...

# 阶段 1：编 Rust 核心 → target/release/librustdesk.so
cargo build --locked --lib --features flutter --release

# 阶段 2：编 Flutter 前端 → flutter/build/linux/x64/release/bundle/neilico
cd flutter && flutter pub get && flutter build linux --release
```

**只编 Linux 时哪些能跳过**：

* **不需要 vcpkg / ffmpeg**：上游只有 `--hwcodec`（硬件编解码）才走 vcpkg+ffmpeg；
  `--features flutter` 单特性即可出可运行客户端（`build.py:315 get_features()` 逻辑）。
* **不需要 Android NDK / Xcode / MSVC**：它们的依赖只在对应平台的构建分支里出现。
* **必须先有桥接代码**：`src/lib.rs:35` 在 `feature="flutter"` 下 `mod bridge_generated;`，
  且 `flutter/.gitignore` 忽略了 `lib/generated_bridge.dart` —— 不生成则 Rust 与 Flutter 都编不过。

### 3.3 Linux 系统依赖（上游 CI `flutter-build.yml:1660-1691` 清单）

`clang cmake ninja-build pkg-config libgtk-3-dev libssl-dev(→openssl-sys)
libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libpulse-dev libva-dev
libayatana-appindicator3-dev libasound2-dev libxdo-dev libxcb-randr0-dev
libxcb-shape0-dev libxcb-xfixes0-dev libxfixes-dev libclang-dev nasm`

* `libxdo` 在本仓库被 **patch 成 stub**（`Cargo.toml:221` → `libs/libxdo-sys-stub`），
  理论上可无 libxdo；但 `libssl-dev`(openssl-sys)、gstreamer、pulse 是硬依赖。
* 本机当前缺 `libssl-dev` / gstreamer-dev / pulse-dev 等 → `openssl-sys`、`gstreamer-sys`
  阶段失败；需 root 安装（见 §6 状态）。

### 3.4 关键环境变量

| 变量 | 作用 |
| :-- | :-- |
| `NEILICO_ID_SERVER` | 构建期注入默认 hbbs 地址（§2.1） |
| `NEILICO_PUB_KEY` | 构建期注入默认公钥（§2.1） |
| `NEILICO_APP_NAME` | 构建期覆盖应用名（默认 `NEILICO`） |
| `VCPKG_ROOT` | 仅 `--hwcodec` 时需要 |

---

## 4. CI 矩阵方案（GitHub Actions，本轮不真跑）

参考上游 `.github/workflows/bridge.yml` + `flutter-build.yml`。建议我们自己的矩阵：

| job | runner | 关键步骤 | 产物 |
| :-- | :-- | :-- | :-- |
| `bridge` | ubuntu-22.04 | 固定 Rust + 固定 Flutter；`cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked`；跑 codegen；**上传桥接产物** | `src/bridge_generated.rs`、`*.io.rs`、`flutter/lib/generated_bridge.dart(.freezed.dart)`、`bridge_generated.h` |
| `linux-x86_64` | ubuntu-22.04 | 装 §3.3 依赖；（可选 vcpkg 仅 hwcodec）→ `cargo build --locked --lib --features flutter --release` → `flutter build linux --release` | `bundle/`、`.deb` |
| `windows-x86_64` | windows-2022 | 同 Linux + 若 hwcodec 则 `run-vcpkg`(x64-windows-static)；`flutter build windows --release` | `neilico.exe`、MSI（`res/msi`） |
| `macos-aarch64` | macos-14 | `cargo build --features flutter --release` → `flutter build macos --release`；Developer ID 签名 + 公证 | `NEILICO.app`、`.dmg` |

要点：

1. **桥接产物只生成一次**（`bridge` job），三平台构建 job 下载同一份 —— 避免每台都装 codegen。
2. **锁 Flutter 版本**：上游用 `FLUTTER_VERSION: 3.24.5`（`flutter-build.yml:28`）。我们应固定一个版本；
   Flutter 版本漂移会改变生成的桥接代码与 `pubspec.lock`。
3. Windows 需 `vcpkg` 装 ffmpeg **仅当** `--hwcodec`；最小构建可先不开。
4. macOS 需 Developer ID 签名 + 公证（否则更新会被 Gatekeeper 拦）；bundle id 已改 `local.neilico.neilico`。
5. 每个产物附 `BUILD-INFO`（commit、Rust/Flutter 版本、构建时间），与 `neilico/rust-core/VERSIONS.yaml` 呼应。
6. 用 §3.4 的环境变量注入生产服务器地址与公钥（**不要把公网地址写死进源码再提交**）。

---

## 5. AGPL-3.0 合规

| 要求 | 落实 |
| :-- | :-- |
| (a) 保留上游 LICENSE | 仓库根 `LICENCE`（AGPL-3.0）**原样保留** |
| (b) 仓库根 `NOTICE` | 已新增 `NOTICE`：基于 rustdesk/rustdesk（AGPL-3.0）、上游 tag/commit、**逐条列修改**、上游地址、我们的源码地址 |
| (c) 关于页显示源码地址 | §2.5（`desktop_setting_page.dart:2579,2600`） |
| 不删改上游版权 | `LICENCE` 与关于页 Purslane 版权行均保留 |

依据 AGPL-3.0 §5（显著声明修改、保留版权）与 §13（网络交互须提供 Corresponding Source）。
对应源码仓库：**https://github.com/aceneil/neilico-client**（`rustdesk-fork` 将来并入该组织下独立仓库后更新）。

---

## 6. 本轮状态

* **已完成的改动**：§2.1–§2.5 全部源码/资源改动（见 `git diff --stat`，60 文件变更）。
* **已生成**：桥接代码（5 个文件）、`NOTICE`、本文件。
* **构建状态**：Rust 核心尚未编过 —— 宿主机缺 `libssl-dev` / gstreamer-dev / pulse-dev 等
  系统库，`openssl-sys`、`gstreamer-sys` 阶段失败；等依赖装好后重跑 §3.2。
  （曾尝试用 `apt-get download` + `dpkg-deb -x` 免 root 抠 gstreamer/pulse 并接好，
  能过 `gstreamer-sys`；但 `openssl` 同样缺，已按指示停止逐库抠取，改为等系统级安装。）

---

## 7. 已知残留（下一轮要做）

| # | 残留 | 位置 | 处理建议 |
| :-- | :-- | :-- | :-- |
| 1 | 打包文件名/路径仍叫 `rustdesk` | `res/rustdesk.desktop`、`res/rustdesk.service`、`res/rpm*.spec`、`res/PKGBUILD`、`build.py` 多处 `tmpdeb/usr/share/rustdesk` | 重命名文件 + 更新 `build.py` 引用 |
| 2 | Android `namespace` / kotlin 包名仍是 `com.carriez.flutter_hbb` | `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/*`、`AndroidManifest.xml:4`、`build.gradle:85` | 搬目录 + 改 `package` 声明 + `namespace` |
| 3 | 界面多处 `rustdesk.com` 链接（隐私/文档/下载/定价，移动端设置页显示 "rustdesk.com"） | `flutter/lib/common.dart:3741`、`desktop_setting_page.dart:2557,2565`、`connection_page.dart:44`、`desktop_home_page.dart:438,531,542,548`、`mobile/pages/settings_page.dart:39,1033,1066,1179,1184` 等 | 指向我们官网/文档，或删除；关于页 Website 现仍指上游（作为署名保留） |
| 4 | 应用内 logo `flutter/assets/icon.svg` 仍是上游图形（`loadIcon` 已优先生效新 `assets/icon.png`，SVG 仅是回退） | `flutter/assets/icon.svg` | 换 NEILICO 矢量图 |
| 5 | `libs/hbb_common` 仍是**上游子模块**，我们的改动在其工作树内、未 fork | `.gitmodules` | 换成我们的 fork 或改为 vendored 目录，否则 `git submodule update` 会覆盖改动 |
| 6 | 默认服务器默认值是内网 IP `192.168.1.10` | `config.rs:121` | 发行前用 `NEILICO_ID_SERVER` 换公网域名重编 |
| 7 | `pubspec.lock` 被本机 Flutter 3.47 的 `pub get` 重写（120 行） | `flutter/pubspec.lock` | 与 CI 锁定的 Flutter 版本对齐后再定稿 |
| 8 | 提权服务 / 系统级组件（uinput、Wayland 免打扰、`res/DEBIAN`）的命名与签名 | `src/ipc`、`res/DEBIAN` | 视发行形态跟进 |
| 9 | 未做 Windows/macOS/Android 真编与签名 | — | 见 §4 |
| 10 | `is_public()` 判据里的 `rustdesk.com`（判断"是否官方服务器"） | `src/common.rs:1175` | 非品牌问题，可保留或补我们的域名 |

---

_本文件对上游 tag 1.5.0（commit `fada664…`）有效。_

---

## 8. 本轮（2026-10）：脱敏 + 公开仓库 + Windows CI 出包

### 8.1 脱敏（0 命中铁闸）

| 位置 | 改动 |
| :-- | :-- |
| `libs/hbb_common/src/config.rs` | `NEILICO_ID_SERVER` 默认值（原为内网 IP）→ `your-server.example.com`；`RS_PUB_KEY` 默认值（原为真实 hbbs 公钥）→ 占位符 `YOUR_HBBS_PUBLIC_KEY` |
| `docs/REBRAND.md` | 内网 IP / 本机绝对路径 / 真实公钥 → 占位符（`192.168.1.10`、`$HOME/...`、`YOUR_HBBS_PUBLIC_KEY`） |

验收：对「原内网网段」与「本机家目录绝对路径」两个模式，在**父仓跟踪文件**与
**`libs/hbb_common` 工作树**中均为 **0 命中**。为避免把模式串本身写进仓库而再次命中，
具体正则见本轮任务单，此处不复写。

真实服务器地址/公钥只在**构建期**注入（`NEILICO_ID_SERVER` / `NEILICO_PUB_KEY`），
CI 从仓库变量 `vars.NEILICO_ID_SERVER` / 密钥 `secrets.NEILICO_PUB_KEY` 读取；
未配置时保留源码占位符，仓库内**不含**任何真实内网地址与密钥。

### 8.2 子模块处置（对应 §7 #5）

`libs/hbb_common` 由 **git 子模块** 改为 **vendored 目录**（删除 `.gitmodules`，
工作树文件直接入库）。理由：fork 的改动在其本地提交里，上游 `rustdesk/hbb_common`
没有这些提交，CI `actions/checkout`（子模块）会拉取失败；vendored 后仓库自包含。

### 8.3 CI（`.github/workflows/neilico-build.yml`）

| job | runner | 说明 |
| :-- | :-- | :-- |
| `bridge` | ubuntu-22.04 | flutter_rust_bridge 1.80.1 生成桥接代码，产物给三平台共用 |
| `build-windows` ★ | windows-2022 | vcpkg(x64-windows-static) + Rust 1.75 + Flutter 3.24.5 + 自定义引擎；产出 `neilico-windows-x64.zip`（可运行目录）并 upload-artifact |
| `build-linux` | ubuntu-latest | `continue-on-error: true` |
| `build-macos` | macos-latest | `continue-on-error: true` |
| `release` | ubuntu-latest | 仅 `v*` tag 触发，挂 Release |

* 触发：`push`（`neilico`/`main` 分支、`v*` tag）+ `workflow_dispatch`。
* 与上游一致：Flutter 3.24.5（桥接 3.22.3）、Rust 1.75、LLVM 15.0.6、vcpkg `9e593bb`；
  Windows 用上游同款自定义引擎 `rustdesk/engine` 与 Flutter dropdown 补丁。
* 与上游不同：Windows **不走 `build.py`**，直接 `cargo build --features flutter,hwcodec,vram`
  + `flutter build windows`，再打 zip（避开 `build.py` 里对 virtual-display dylib 的强拷贝与
  便携打包器）。
* `workflow_dispatch` 可传 `hwcodec=false` 走最小构建（不建 ffmpeg，仅 vcpkg opus）。

### 8.4 公开仓库

`https://github.com/aceneil/neilico-client`（公开）。保留 `LICENCE`（AGPL-3.0 原文）
+ `NOTICE`（修改声明、上游 tag/commit、源码地址），AGPL §5/§13 合规。
