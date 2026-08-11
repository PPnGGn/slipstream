# Slipstream

Cross-platform VPN client built with Flutter. VPN traffic is handled by [Xray-core](https://github.com/XTLS/Xray-core) through a separate Go wrapper — **slipstream-core** (`../slipstream-core`): it wraps Xray lifecycle (start/stop, config, logging, tun2socks) and is compiled into native libraries via [gomobile](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile) (`.aar` on Android, `.xcframework` on iOS).

## Status

Early MVP — Android and iOS only. Core connect/disconnect flow works; UI and protocol coverage are minimal.

## Supported protocols

| Protocol | Transport / security |
|----------|----------------------|
| VLESS    | Reality (TCP)        |
| Shadowsocks | TCP              |

## Subscription input

- `https://` / `http://` subscription links (base64-encoded server lists)
- Direct `vless://` and `ss://` URIs
- Raw Xray JSON configs

## Features

- Add, refresh, and remove subscriptions
- Server list with country detection from server names
- Connect / disconnect, switch server while connected
- Connection status, uptime, and traffic stats
- Xray log viewer

## Architecture

```
Flutter (Dart)  →  Pigeon  →  Kotlin / Swift  →  slipstream-core (Go)  →  Xray-core
```

- **Flutter app** — UI, subscription parsing, state (BLoC)
- **slipstream-core** — Go wrapper around Xray-core; platform-specific tunnel glue (TUN fd on Android, `NEPacketTunnelFlow` on iOS)
- **Pigeon** — Dart ↔ native VPN bridge
- **Android** — `VpnService` + slipstream-core AAR
- **iOS** — Network Extension (Packet Tunnel) + slipstream-core xcframework

## Setup

Build the native core (from the `slipstream` directory):

```bash
make build-core-android   # Android
make build-core-ios       # iOS
```

Generate code:

```bash
dart run build_runner build --delete-conflicting-outputs
make generate-vpn-api
```

Then run with Flutter as usual (`flutter run`).
