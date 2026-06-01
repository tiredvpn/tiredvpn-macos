# TiredVPN — macOS Client

[![Release](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/release.yml/badge.svg)](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/release.yml)
[![CI](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/tiredvpn/tiredvpn-macos/actions/workflows/ci.yml)

> **[!WARNING]**
> **Work in progress. Nothing here works yet.**
>
> The UI is a scaffold, the VPN tunnel is not connected end-to-end, and there
> are no signed releases. If you're looking for something that actually runs -
> come back later. Stars and issues are welcome regardless.

macOS GUI client for TiredVPN. SwiftUI app + `NEPacketTunnelProvider` extension
that statically links `libtiredvpn.a` - a c-archive built from the
[tiredvpn/tiredvpn](https://github.com/tiredvpn/tiredvpn) Go core.

## Architecture

```
┌──────────────────────────────┐         ┌──────────────────────────────────┐
│      tiredvpn (Go)           │         │     tiredvpn-macos (Swift)       │
│                              │         │                                  │
│  internal/strategy           │         │  TiredVPN.app                    │
│  internal/tunnel             │  build  │  ├─ SwiftUI (UI, settings)       │
│  internal/client             │ ──c-ar→ │  └─ TiredVPNTunnel.appex         │
│  internal/tun/tun_darwin.go  │ libtv.a │     ├─ PacketTunnelProvider      │
│  cmd/tiredvpn/cgo_darwin.go  │ + .h    │     ├─ libtiredvpn.a (universal) │
└──────────────────────────────┘         │     └─ tiredvpn.h                │
                                         └──────────────────────────────────┘
```

## Build

Requires macOS 12+, Xcode 16, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
# 1. Build Go core (libtiredvpn.a + libtiredvpn.h) from source
git clone https://github.com/tiredvpn/tiredvpn tiredvpn-oss
cd tiredvpn-oss
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 SDKROOT=$SDKROOT \
  go build -buildmode=c-archive -o ../Vendor/libtiredvpn-arm64.a ./cmd/tiredvpn/
GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 SDKROOT=$SDKROOT \
  go build -buildmode=c-archive -o ../Vendor/libtiredvpn-amd64.a ./cmd/tiredvpn/
lipo -create ../Vendor/libtiredvpn-arm64.a ../Vendor/libtiredvpn-amd64.a \
  -output ../Vendor/libtiredvpn.a
cp ../Vendor/libtiredvpn-arm64.h ../Vendor/libtiredvpn.h
cd ..

# 2. Generate Xcode project and open
xcodegen generate
open TiredVPN.xcodeproj
```

## CI / Releasing

CI builds on `macos-15`. Releases are unsigned DMGs - on first launch right-click
the app and choose Open to bypass Gatekeeper.

To cut a release: tag and push.

```sh
git tag v0.x.y && git push origin v0.x.y
```

## Layout

- `TiredVPN/` - main SwiftUI app (TunnelManager, ConfigStore)
- `TiredVPNTunnel/` - `NEPacketTunnelProvider` extension and Go bridge
- `Vendor/` - built `libtiredvpn.{a,h}` (gitignored)
- `project.yml` - XcodeGen spec (source of truth, `.xcodeproj` not committed)

## Related

- Go core: <https://github.com/tiredvpn/tiredvpn>
