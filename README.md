**English** | [简体中文](README.zh-CN.md)

# NEILICO Client

NEILICO Client is the official remote-desktop client for NEILICO. It is a modified version of `rustdesk/rustdesk` 1.5.0 and is distributed under **AGPL-3.0**. This repository also contains the Flutter device and policy management app migrated from the server repository under `app/`, plus the `rust-core/` integration skeleton.

## Platform status

| Platform | Status | Current delivery |
| :-- | :-- | :-- |
| Windows x64 | ✅ Package available | [Release v1.5.0-neilico.1](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1) |
| Linux x64 | ⏳ Pending | Manual CI exists in [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml), but it is allowed to fail and has no release package |
| macOS | ⏳ Pending | Manual CI exists in [`.github/workflows/neilico-build.yml`](.github/workflows/neilico-build.yml), but it is allowed to fail and has no release package |
| Android | ⏳ Pending | The upstream Android toolchain remains in the repository, but no NEILICO package has been released |

Status is based on the repository and GitHub Releases. “Pending” does not mean released or accepted.

## Download

For Windows, download the current [v1.5.0-neilico.1 Release](https://github.com/aceneil/neilico-client/releases/tag/v1.5.0-neilico.1). You can also publish the package through your own NEILICO control plane:

```text
https://<SERVER>/downloads/neilico-client-windows-x64.zip
```

The control-plane download directory is configured with `NEILICO_DOWNLOADS_DIR`, and filenames must match the download allowlist. The current Release asset is named `neilico-windows-x64.zip`, while the control-plane package must be named `neilico-client-windows-x64.zip`. Rename it when placing it in the download directory.

## Build

The pinned toolchain is **Flutter 3.24.5** and **Rust 1.75**. The core Windows build is:

```bash
cargo build --features "flutter,hwcodec,vram"
cd flutter
flutter build windows --release
```

The `hwcodec` and `vram` features require the corresponding codec and vcpkg dependencies. Linux, macOS, and Android have different prerequisites and output layouts; their workflows are not release acceptance targets yet. See [`docs/BUILD.md`](docs/BUILD.md) for detailed prerequisites, CI locations, and build notes.

## Inject the server

Inject the hbbs address and server public key before building:

```bash
NEILICO_ID_SERVER=<HOST> \
NEILICO_PUB_KEY=<BASE64_PUBLIC_KEY> \
cargo build --features "flutter,hwcodec,vram"
```

CI reads `vars.NEILICO_ID_SERVER` and `secrets.NEILICO_PUB_KEY`. **Without these values, the build contains the placeholders `your-server.example.com` and `YOUR_HBBS_PUBLIC_KEY` and cannot connect to any server.** Replace both placeholders with your own hbbs/hbbr address and `id_ed25519.pub` public key, then rebuild. Never commit or embed the private key.

## Flutter management app

[`app/`](app/) is our Flutter device and policy management app. It manages device lists, enrollment state, remote-control policy, tunnel mode, and Mesh policy. `rust-core/` is the kernel integration skeleton. The migration source is server-repository commit `88e0b974b20c927bc3d98798078217c01c60c692`; `git subtree` preserves that source history.

The management app is not a remote-desktop client and exposes no connection button or connection entry point. **Every connection is initiated by the NEILICO client itself; the web UI is management-only.**

## AGPL-3.0 compliance

This is a modified version of `rustdesk/rustdesk` 1.5.0 and is subject to the **GNU Affero General Public License v3.0**:

- Keep the upstream [`LICENCE`](LICENCE) text unchanged. The identical [`LICENSE`](LICENSE) copy is provided for GitHub license detection.
- Keep [`NOTICE`](NOTICE), which records upstream tag `1.5.0`, upstream commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`, our changes, and the Corresponding Source location.
- Corresponding Source: [github.com/aceneil/neilico-client](https://github.com/aceneil/neilico-client).
- Upstream copyright, license text, and attribution remain intact. Details are in [`docs/AGPL.md`](docs/AGPL.md).

## Documentation

The bilingual [`docs/README.md`](docs/README.md) indexes project guides and all upstream documentation translations. Long-form build and licensing details are in [`docs/BUILD.md`](docs/BUILD.md) and [`docs/AGPL.md`](docs/AGPL.md).
