# macOS Client — Implementation Plan

> Branch: `feat/macos-client`
> Target: separate GUI repository `tiredvpn-macos` that links a `c-archive` produced from this Go core.
> Status: phase 1-2 in progress.

## Architecture

The same model as Android:

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

Core is a self-contained Go library. The Swift app handles:
- UI, settings persistence (Keychain via `protocolConfiguration.providerConfiguration`)
- `NETunnelProviderManager` lifecycle (install profile, start/stop tunnel)
- `NEPacketTunnelProvider` creates `NEPacketTunnelNetworkSettings`, extracts the utun fd from `packetFlow`, and hands it to Go
- Calls into Go via C-ABI exports

Go core does only what it does today: probe strategies, drive the tunnel, read/write packets on the fd.

## Why c-archive (not c-shared / dylib)

NetworkExtension targets run inside Apple's app sandbox. Loading a dylib from the bundle is restricted and the App Store review rejects it. `c-archive` is statically linked into the extension at build time — no runtime loader, no entitlement issues.

## Why fd-from-host (not utun-from-Go)

For the GUI flow the utun fd is created by `NEPacketTunnelProvider`. We get it via:
```swift
let fd = self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
```
This is the same trick WireGuardKit uses; App Store accepts it. Go's role is just to read/write packets on that fd and run the strategies — `internal/tun/tun_darwin.go` (CLI mode) is the fallback that opens utun itself for debugging without the GUI.

`MacOSMode` (in `client.Config`) mirrors `AndroidMode`: disables `os/exec` route manipulation, ICMP probes, and other side effects that are the host's job in the NE flow.

## Phases

### Phase 1 — Go core: darwin TUN + MacOSMode (THIS BRANCH)

- [x] `internal/tun/tun_darwin.go` — utun via `PF_SYSTEM`/`SYSPROTO_CONTROL`, full `TUNDevice` API parity with `tun_linux.go` (Create, Configure, ConfigureSubnet, UpdatePeerIP, UpdateLocalIP, Close, Read/Write, SetReadDeadline)
- [x] Extend `internal/tun/android.go` build tag to include `darwin` — `CreateTUNFromFd` is what the NE will call
- [x] `MacOSMode bool` in `internal/client/client.Config` and `cmd/tiredvpn/config.go`
- [x] No changes to `protect` package (existing `!android && !linux` stub already covers darwin as no-op)

Acceptance: `GOOS=darwin GOARCH=arm64 go build ./...` clean. Tests pass on Linux.

### Phase 2 — Go core: CGo exports + c-archive (THIS BRANCH)

- [x] `cmd/tiredvpn/cgo_darwin.go` (build tag `//go:build darwin && cgo`)
- [x] Exported C symbols:
  - `TiredvpnStart(argsJSON char*) int`
  - `TiredvpnStop() void`
  - `TiredvpnSetTunFd(fd int)`
  - `TiredvpnSendCommand(cmdJSON char*) char*`
  - `TiredvpnSetCallbacks(state_cb, log_cb uintptr_t)`
  - `TiredvpnFreeString(char*)` — for memory the Go side allocated
- [x] Callbacks invoked via cached C function pointers — no JNI thread-attach complexity
- [x] `Makefile` targets:
  - `build-macos-lib` → universal `libtiredvpn.a` via `lipo` (amd64 + arm64)
  - `build-macos-cli` → standalone `tiredvpn-macos-{arm64,amd64}` for CLI debug
- [x] Generated `libtiredvpn.h` checked-in path: `build/macos/libtiredvpn.h`

Acceptance: archive builds on a macOS runner (CI fixture or local). Header is well-formed C.

### Phase 3 — Repo bootstrap `tiredvpn-macos`

- SwiftPM project: app target + extension target
- `NETunnelProviderManager` setup screen, manual server config (paste TOML/QR), keychain storage
- Smoke test: install configuration profile, click Connect, verify state callbacks

### Phase 4 — PacketTunnelProvider wiring

- Apply `NEPacketTunnelNetworkSettings` (IP from server response, routes, DNS, MTU)
- Pull utun fd → `TiredvpnSetTunFd` → `TiredvpnStart(jsonConfig)`
- Wire `state_cb`/`log_cb` → main app via Darwin notifications or shared App Group
- `handleAppMessage` for runtime commands (port hop, status query)

### Phase 5 — UI polish

- Strategy picker, real-time status, log viewer, QR config import (we already have `go-qrcode` server-side; client-side decode via `Vision.framework`)

### Phase 6 — Signing & distribution

- Apple Developer Program enrollment
- Entitlements: `com.apple.developer.networking.networkextension` = `["packet-tunnel-provider"]`
- Notarization pipeline (`notarytool`), `.dmg` build, GitHub Actions on `macos-latest`
- Optional: App Store submission later

## Open questions

1. **App Store vs notarized .dmg**: starting with notarized .dmg (faster iteration). App Store later.
2. **Min macOS version**: target macOS 12 Monterey (async/await, mature SwiftUI).
3. **Universal binary**: yes, ship arm64 + x86_64.
4. **Config format parity**: reuse TOML schema from `internal/config`, same QR encoding as Android.

## Out of scope (for now)

- iOS port (would reuse 90% of darwin code but needs different entitlements + IAP)
- Menu bar app variant (post-MVP, on top of NE)
- Wireguard-style kernel sysex (we don't need that — utun via NE is sufficient)

---

# Implementation Plan (Phases 3-6)

## Фактическое состояние на 2026-05-22

Сверка с `tiredvpn-oss@feat/macos-client`:

- **Phase 1-2 готовы, но не закоммичены** (unstaged в OSS):
  - `internal/tun/tun_darwin.go` — 302 строки
  - `cmd/tiredvpn/cgo_darwin.go` — 243 строки, 7 C-экспортов: `TiredvpnStart`, `TiredvpnStop`, `TiredvpnSetTunFd`, `TiredvpnSetCallbacks`, `TiredvpnSendCommand`, `TiredvpnFreeString`, `TiredvpnVersion`
  - `MacOSMode bool` в `internal/client/client.Config`
  - Makefile-таргеты `build-macos-lib` / `build-macos-cli`, универсальный `.a` через `lipo`
- **Phase 3-6 не начаты** — репо `tiredvpn-macos` содержит только этот PLAN.md.

## Phase 0 — закрыть Go-ядро (1 день)

Прежде чем стартовать Swift — финализировать unstaged в `tiredvpn-oss@feat/macos-client`:

1. Доступ к macOS-машине (CI runner `macos-latest` или локалка) для проверки `make build-macos-lib`. Без этого `libtiredvpn.a` собрать нельзя — нужен `clang`/`lipo`/SDKROOT.
2. Unit-тест на `tun_darwin.go` (хотя бы Create/Close в CLI-режиме).
3. Коммит + PR в OSS, тэг `v1.x-macos-core`.
4. Артефакты сборки (`libtiredvpn.a` + `.h`) публиковать в GitHub Release — Swift-репо будет тянуть их по версии.

**Acceptance**: `make build-macos-lib` зелёный на CI; `.a` + `.h` лежат в релизе.

## Phase 3 — bootstrap `tiredvpn-macos` (2-3 дня)

```
tiredvpn-macos/
├── TiredVPN.xcodeproj           # Xcode project (не SwiftPM — extension targets требуют .xcodeproj)
├── TiredVPN/                    # main app (SwiftUI)
│   ├── TiredVPNApp.swift
│   ├── ContentView.swift
│   ├── TunnelManager.swift      # обёртка над NETunnelProviderManager
│   ├── ConfigStore.swift        # Keychain + App Group
│   └── Assets.xcassets
├── TiredVPNTunnel/              # NEPacketTunnelProvider extension
│   ├── PacketTunnelProvider.swift
│   ├── GoBridge.swift           # тонкая Swift-обёртка над C API
│   └── Info.plist
├── Vendor/
│   ├── libtiredvpn.a            # из release, не в git (LFS или fetch-script)
│   └── libtiredvpn.h
├── Scripts/fetch-core.sh        # качает .a/.h по тегу версии из OSS
└── README.md
```

**Задачи:**

- Xcode-проект: 2 таргета (App + AppEx), bridging header для `libtiredvpn.h`, линк `-ltiredvpn -framework NetworkExtension -framework Security`.
- App Group `group.com.tiredvpn.macos` для шары между App и Extension.
- Entitlements: `com.apple.developer.networking.networkextension = ["packet-tunnel-provider"]`, `com.apple.security.application-groups`.
- `TunnelManager`: `NETunnelProviderManager.loadAllFromPreferences` → installFirstTime → `startVPNTunnel`.
- `ConfigStore`: парс TOML (через `TOMLKit` SwiftPM) или сразу JSON-схема, что отдаёт сервер; хранить в Keychain через `providerConfiguration`.
- Smoke screen: «Paste config / Connect / Status».

**Acceptance**: app собирается, профиль ставится в System Settings → VPN, кнопка Connect доходит до extension (видно в Console.app).

## Phase 4 — PacketTunnelProvider ↔ Go (3-5 дней)

Самый рисковый кусок. Порядок:

1. **Network settings**: `NEPacketTunnelNetworkSettings` с IP/маской/DNS/MTU из ответа сервера (`ConnectFn` отдаёт `LocalIP`/`PeerIP`). `IPv4Settings.includedRoutes = [NEIPv4Route.default()]`.
2. **fd extraction**:
   ```swift
   let fd = self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
   TiredvpnSetTunFd(fd)
   ```
   Это нелегальный KVC-трюк, но он же используется в WireGuardKit и пропускается review. Fallback: если KVC сломается на будущих macOS — `dup()` через приватный `NEPacketTunnelFlow`.
3. **Start**: сериализовать конфиг в JSON (с `macos_mode: true`), `TiredvpnStart(jsonCStr)`.
4. **Callbacks** (state/log) — C function pointers. На Swift стороне это `@convention(c)` глобальные функции, передающие данные в `DispatchQueue.main` и через Darwin notifications / `NSDistributedNotificationCenter` в основное приложение. Альтернатива — писать состояние в файл в App Group и в main app поллить через `DispatchSource.makeFileSystemObjectSource`.
5. **handleAppMessage**: рулим runtime-командами (`port_hop`, `status`) — каждое сообщение → `TiredvpnSendCommand(jsonStr)` → возврат JSON через `TiredvpnFreeString`.
6. **stopTunnel**: `TiredvpnStop()` → дождаться idle → `completionHandler()`.
7. **Sleep/Wake**: подписаться на `NSWorkspace.willSleepNotification` (только в App, не в extension); extension сам получит `wake` через NE.

**Edge cases**:

- IPv6 — пока выключить (`IPv6Settings = nil`), как и на Android.
- App Sandbox + extension не имеет доступа к `os/exec` → проверить, что `MacOSMode` действительно блокирует все side effects (там уже стоит флаг).
- Логи Go идут через `log_cb` — буфер на 1 МБ в App Group, ротация.

**Acceptance**: на тестовом сервере (`ss.tazhate.com:995`) пингуется внешний IP через туннель, latencyMs показывается в UI, дисконнект чистый.

## Phase 5 — UI (2-3 дня)

- Главный экран: статус (Disconnected/Connecting/Connected + стратегия + latency), кнопка Connect/Disconnect.
- Settings: список конфигов (Keychain), импорт TOML из файла + QR-сканер через `AVCaptureSession` + `Vision.VNDetectBarcodesRequest` (декод reuses тот же base64-формат, что Android).
- Лог: окно с tail-ом из App Group, кнопка «Export logs».
- Strategy picker: dropdown с `auto`/конкретная стратегия → отправляется в `providerConfiguration.strategy`.
- Меню-бар иконка (NSStatusItem) с быстрым toggle (это не «menu bar app variant», а просто аксессуар главного окна).

## Phase 6 — подпись и дистрибуция (1-2 дня + Apple review)

- Apple Developer Program (если ещё нет — $99/год, заводится на `tiredvpn`-аккаунт).
- App ID + provisioning profile: 2 идентификатора (`com.tiredvpn.macos`, `com.tiredvpn.macos.tunnel`), оба с NE-capability.
- GitHub Actions на `macos-latest`:
  ```
  fetch libtiredvpn.{a,h} → xcodebuild archive → codesign → notarytool submit → staple → create-dmg → release
  ```
  Секреты: `APPLE_ID`, `APP_PASSWORD` (app-specific), `TEAM_ID`, `CERT_P12_BASE64`, `CERT_PASSWORD`.
- DMG с drag-to-Applications, README с инструкцией «Settings → Privacy → разрешить VPN config».
- Версионирование привязать к OSS: `tiredvpn-macos vX.Y.Z` тянет `libtiredvpn vX.Y.Z` из релиза OSS.

## Риски и развилки

| Риск | Митигация |
|---|---|
| KVC `socket.fileDescriptor` сломают в новой macOS | Документировать; иметь branch на `NEPacketTunnelFlow.readPackets/writePackets` (медленнее, но публичный API) |
| App Store отклонит NE с C-archive | Стартуем с notarized .dmg — App Store отложен |
| `lipo` arm64+amd64 → размер .a ~80 МБ | Принять; релиз качается один раз |
| Go-логи блокируют extension | Async-канал, drop при переполнении |

## Что делать в первую очередь

1. **Сейчас**: достать macOS-машину/CI, прогнать `make build-macos-lib`, закоммитить Go-ветку.
2. **Параллельно**: завести Apple Developer аккаунт (долгая верификация).
3. **Дальше**: Phase 3 bootstrap — это разовый день работы, делает один Swift-агент.

Открытый блокер — доступ к macOS-машине для разработки и CI. Без него Phase 3+ невозможно физически (Xcode только на Darwin).
