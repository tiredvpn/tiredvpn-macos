# TiredVPN — macOS Client

[![Release](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/release.yml/badge.svg)](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/release.yml)
[![CI](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/ci.yml)

macOS GUI client for TiredVPN. A SwiftUI app paired with a `NEPacketTunnelProvider`
extension that statically links `libtiredvpn.a` — a c-archive built from the
[tiredvpn-oss](https://github.com/tiredvpn/tiredvpn-oss) Go core. The app handles
UI, settings, keychain, and the `NETunnelProviderManager` lifecycle; the
extension owns the utun fd and hands it to Go, which runs strategies and
shuttles packets.

## Download

Download the latest DMG from [Releases](https://github.com/tiredvpn/tiredvpn-macos/releases/latest).

## Architecture

```
┌──────────────────────────────┐         ┌──────────────────────────────────┐
│      tiredvpn-oss (Go)       │         │     tiredvpn-macos (Swift)       │
│                              │         │                                  │
│  internal/strategy           │         │  TiredVPN.app                    │
│  internal/tunnel             │  build  │  ├─ SwiftUI (UI, settings)       │
│  internal/client             │ ──c-ar→ │  └─ TiredVPNTunnel.appex         │
│  internal/tun/tun_darwin.go  │ libtv.a │     ├─ PacketTunnelProvider      │
│  cmd/tiredvpn/cgo_darwin.go  │ + .h    │     ├─ libtiredvpn.a (universal) │
└──────────────────────────────┘         │     └─ tiredvpn.h                │
                                         └──────────────────────────────────┘
```

## Prerequisites

- macOS 12+ with Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple Developer account with a Network Extension entitlement (for real
  device runs / distribution)

## Build

```sh
# 1. Pull the Go core artifacts (libtiredvpn.a + libtiredvpn.h) into Vendor/
#    Version is read from Vendor/VERSION or $LIBTIREDVPN_VERSION.
Scripts/fetch-core.sh

# 2. Generate the Xcode project from project.yml
xcodegen generate

# 3. Open and build
open TiredVPN.xcodeproj
```

## CI / Releasing

Releases are built automatically on `macos-14` GitHub runners. To cut a release:

1. Pin the Go core version: `echo "v1.x.y" > Vendor/VERSION`
2. Bump `MARKETING_VERSION` in `project.yml`
3. Tag and push: `git tag v1.x.y && git push origin v1.x.y`

The `release` workflow builds, signs, notarizes, and uploads a DMG to GitHub Releases.
Required secrets: `APPLE_ID`, `APP_PASSWORD`, `TEAM_ID`, `CERT_P12_BASE64`, `CERT_PASSWORD`.

See [`docs/RELEASING.md`](docs/RELEASING.md) for the full runbook.

## Layout

- `TiredVPN/` — main SwiftUI app (TunnelManager, ConfigStore)
- `TiredVPNTunnel/` — `NEPacketTunnelProvider` extension and Go bridge
- `Vendor/` — fetched `libtiredvpn.{a,h}` (gitignored; `VERSION` is tracked)
- `Scripts/fetch-core.sh` — downloads and SHA-256 verifies the core artifacts
- `project.yml` — XcodeGen project spec (source of truth, no checked-in `.xcodeproj`)

## Related

- Go core: <https://github.com/tiredvpn/tiredvpn-oss>
