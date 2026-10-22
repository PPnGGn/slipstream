# Slipstream

Cross-platform VPN client built with Flutter. VPN traffic is handled by [Xray-core](https://github.com/XTLS/Xray-core) through a separate Go wrapper — **slipstream-core** (`../slipstream-core`): it wraps Xray lifecycle (start/stop, config, logging, tun2socks) and is compiled into native libraries via [gomobile](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile) (`.aar` on Android, `.xcframework` on iOS).

## Status

Android is the main platform. iOS builds and works but is frozen (no new features, not re-verified). Desktop
(Windows) is planned.

## Supported protocols

| Protocol | Link scheme |
|----------|-------------|
| VLESS (TCP, WS, gRPC, HTTPUpgrade, XHTTP, mKCP; TLS or Reality) | `vless://` |
| VMess | `vmess://` |
| Trojan | `trojan://` |
| Shadowsocks | `ss://` |
| Hysteria2 | `hy2://`, `hysteria2://` |

Which transports each parser accepts is decided in `lib/features/subscriptions/data/subscription_parser/`.

## Subscription input

- `https://` / `http://` subscription links (base64-encoded server lists)
- Direct share links of the protocols above
- Raw Xray JSON configs

## Features

- Add, refresh, and remove subscriptions
- Server list with country detection from server names
- Connect / disconnect, switch server while connected
- Connection status, uptime, and traffic stats
- Ping for the server list (TCP and QUIC probes)
- Routing: bypass Russia (geosite/geoip), ad blocking, trimmed geo databases downloaded by the app
- Memory monitor of the core (Android)
- Self-update (Android)
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
make generate-vpn-api generate-updater-api generate-device-info-api generate-sync-api
```

Then run with Flutter as usual (`flutter run`).
