# TiredVPN — macOS Client

macOS GUI client for TiredVPN. A SwiftUI app paired with a `NEPacketTunnelProvider`
extension that statically links `libtiredvpn.a` — a c-archive built from the
[tiredvpn-oss](https://github.com/tazhate/tiredvpn-oss) Go core. The app handles
UI, settings, keychain, and the `NETunnelProviderManager` lifecycle; the
extension owns the utun fd and hands it to Go, which runs strategies and
shuttles packets.

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

## Layout

- `TiredVPN/` — main SwiftUI app (TunnelManager, ConfigStore)
- `TiredVPNTunnel/` — `NEPacketTunnelProvider` extension and Go bridge
- `Vendor/` — fetched `libtiredvpn.{a,h}` (gitignored; `VERSION` is tracked)
- `Scripts/fetch-core.sh` — downloads and SHA-256 verifies the core artifacts
- `project.yml` — XcodeGen project spec (source of truth, no checked-in `.xcodeproj`)

## Related

- Go core: <https://github.com/tazhate/tiredvpn-oss>
