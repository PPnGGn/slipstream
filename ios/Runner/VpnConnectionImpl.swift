import Flutter
import NetworkExtension
import os

private let appLog = Logger(subsystem: "vpn.oko", category: "vpnstatus")

/// Decoder for the binary traffic/logs replies the PacketTunnel extension
/// sends back over `handleAppMessage`. Mirrors the encoder in
/// ios/PacketTunnel/PacketTunnelProvider.swift — keep both in sync.
private enum AppMessageWire {
    static func decodeTraffic(_ data: Data) -> (uplink: Int64, downlink: Int64, memory: Int64?)? {
        var r = ByteReader(data: data)
        guard let uplink = r.readUInt64BE(), let downlink = r.readUInt64BE() else { return nil }
        // The memory field is new; a stale extension (mid-upgrade, or a dev
        // build with a version skew) may still reply with the old 16-byte
        // payload — degrade to a missing reading rather than fail decoding.
        let memory = r.readUInt64BE()
        return (
            Int64(bitPattern: uplink),
            Int64(bitPattern: downlink),
            memory.map { Int64(bitPattern: $0) }
        )
    }

    static func decodeLogs(_ data: Data) -> [(level: String, message: String, source: String, timestampMs: Int64)] {
        var r = ByteReader(data: data)
        guard let count = r.readUInt32BE() else { return [] }

        var out: [(level: String, message: String, source: String, timestampMs: Int64)] = []
        out.reserveCapacity(Int(count))
        for _ in 0..<count {
            guard let code = r.readUInt8(),
                  let timestampMs = r.readUInt64BE(),
                  let source = r.readString16(),
                  let message = r.readString32()
            else { break }
            out.append((levelName(code), message, source, Int64(bitPattern: timestampMs)))
        }
        return out
    }

    private static func levelName(_ code: UInt8) -> String {
        switch code {
        case 0: return "debug"
        case 2: return "warning"
        case 3: return "error"
        default: return "info"
        }
    }
}

/// Minimal big-endian byte reader backing [AppMessageWire]'s decoders. Every
/// read fails soft (returns nil) instead of trapping on truncated/malformed
/// data, since this parses IPC input rather than trusted in-process state.
private struct ByteReader {
    let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    private mutating func take(_ length: Int) -> Data? {
        guard length >= 0, offset + length <= data.count else { return nil }
        let start = data.startIndex + offset
        let slice = data.subdata(in: start..<(start + length))
        offset += length
        return slice
    }

    mutating func readUInt8() -> UInt8? {
        take(1)?.first
    }

    mutating func readUInt16BE() -> UInt16? {
        take(2).map { $0.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).bigEndian } }
    }

    mutating func readUInt32BE() -> UInt32? {
        take(4).map { $0.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian } }
    }

    mutating func readUInt64BE() -> UInt64? {
        take(8).map { $0.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).bigEndian } }
    }

    mutating func readString16() -> String? {
        guard let length = readUInt16BE(), let bytes = take(Int(length)) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    mutating func readString32() -> String? {
        guard let length = readUInt32BE(), let bytes = take(Int(length)) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
}

final class VpnConnectionImpl: NSObject, VpnConnection {

    private static let extensionBundleID = "vpn.oko.XrayTunnel"
    private static let socksPort = 10808
    static let appGroupID = "group.vpn.oko"

    private let eventReceiver: VpnEventReceiver
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var trafficTimer: Timer?
    private var lastSentStatus: VpnStatus?

    init(binaryMessenger: FlutterBinaryMessenger) {
        self.eventReceiver = VpnEventReceiver(binaryMessenger: binaryMessenger)
        super.init()
        
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleStatusChange()
        }
    }

    deinit {
        if let obs = statusObserver { NotificationCenter.default.removeObserver(obs) }
    }


    func start(config: VpnConfigMessage, completion: @escaping (Result<VpnResult, Error>) -> Void) {
        loadOrCreateManager { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.success(VpnResult(successful: false, error: error.localizedDescription)))
            case .success(let manager):
                self?.startTunnel(manager: manager, config: config, completion: completion)
            }
        }
    }

    func stop(completion: @escaping (Result<VpnResult, Error>) -> Void) {
        stopTrafficPolling()
        manager?.connection.stopVPNTunnel()
        completion(.success(VpnResult(successful: true)))
    }

    func geoAssetDir() throws -> String? {
        let fm = FileManager.default
        let base: URL
        if let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            base = container.appendingPathComponent("geo", isDirectory: true)
        } else {
            appLog.error("geoAssetDir: App Group \(Self.appGroupID, privacy: .public) unavailable, using app-local dir")
            base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true)
                .appendingPathComponent("geo", isDirectory: true)
        }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        var mutableBase = base
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableBase.setResourceValues(resourceValues)
        return base.path
    }

    func xrayCoreVersion() throws -> String {
        // Android-only feature (see the pigeon doc comment) — xray-core runs
        // inside the PacketTunnel extension here, not this process.
        "n/a"
    }

    func getStatus(completion: @escaping (Result<VpnStatusMessage, Error>) -> Void) {
        guard manager != nil else {
            loadExistingManager { [weak self] in
                completion(.success(self?.currentStatusMessage() ?? VpnStatusMessage(status: .disconnected, connectedAtEpochMs: nil)))
            }
            return
        }
        completion(.success(currentStatusMessage()))
    }

    private func loadExistingManager(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error {
                appLog.error("loadExistingManager: \(error.localizedDescription, privacy: .public)")
            }
            self?.manager = managers?.first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == Self.extensionBundleID
            }
            completion()
        }
    }

    private func currentStatusMessage() -> VpnStatusMessage {
        let status: VpnStatus = manager.map { vpnStatus(from: $0.connection.status) } ?? .disconnected
        if status == .connected {
            startTrafficPolling()
        }
        return VpnStatusMessage(status: status, connectedAtEpochMs: connectedAtEpochMs())
    }

    private func connectedAtEpochMs() -> Int64? {
        manager?.connection.connectedDate.map { Int64($0.timeIntervalSince1970 * 1000) }
    }


    private func loadOrCreateManager(
        completion: @escaping (Result<NETunnelProviderManager, Error>) -> Void
    ) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error {
                completion(.failure(error))
                return
            }
            
            let existing = managers?.first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == Self.extensionBundleID
            }
             
            let manager: NETunnelProviderManager
            if let existing {
                appLog.notice("loadOrCreateManager: reusing existing manager (count=\(managers?.count ?? 0, privacy: .public))")
                manager = existing
            } else {
                appLog.notice("loadOrCreateManager: creating NEW manager (count=\(managers?.count ?? 0, privacy: .public))")
                manager = NETunnelProviderManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = Self.extensionBundleID
                proto.serverAddress = "slipstream"
                manager.protocolConfiguration = proto
                manager.localizedDescription = "Slipstream"
            }
            
          manager.isEnabled = true
            self?.manager = manager
            completion(.success(manager))
        }
    }

    private func startTunnel(
        manager: NETunnelProviderManager,
        config: VpnConfigMessage,
        completion: @escaping (Result<VpnResult, Error>) -> Void
    ) {
        if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
            var providerConfiguration: [String: Any] = [
                "configJson": config.configJson,
                "socksPort": Self.socksPort,
            ]
            if let geoAssetDir = config.geoAssetDir {
                providerConfiguration["geoAssetDir"] = geoAssetDir
            }
            proto.providerConfiguration = providerConfiguration
        }
        manager.saveToPreferences { error in
            if let error {
                completion(.success(VpnResult(successful: false, error: error.localizedDescription)))
                return
            }
            manager.loadFromPreferences { error in
                if let error {
                    completion(.success(VpnResult(successful: false, error: error.localizedDescription)))
                    return
                }
                do {
                    var options: [String: NSObject] = [
                        "configJson": config.configJson as NSObject,
                        "socksPort": NSNumber(value: Self.socksPort),
                    ]
                    if let geoAssetDir = config.geoAssetDir {
                        options["geoAssetDir"] = geoAssetDir as NSObject
                    }
                    let session = manager.connection as! NETunnelProviderSession
                    appLog.notice("startTunnel: calling startVPNTunnel; current status.rawValue=\(session.status.rawValue, privacy: .public)")
                    
                    try session.startVPNTunnel(options: options)
                    appLog.notice("startTunnel: startVPNTunnel returned OK")
                    completion(.success(VpnResult(successful: true)))
                } catch {
                    appLog.error("startTunnel: startVPNTunnel THREW: \(error.localizedDescription, privacy: .public)")
                    completion(.success(VpnResult(successful: false, error: error.localizedDescription)))
                }
            }
        }
    }

    private func handleStatusChange() {
        guard let connection = manager?.connection else {
            appLog.error("handleStatusChange: manager/connection is nil — status dropped")
            return
        }
        let status = connection.status
        appLog.notice("handleStatusChange: NEVPNStatus.rawValue=\(status.rawValue, privacy: .public) -> \(String(describing: self.vpnStatus(from: status)), privacy: .public)")

        switch status {
        case .connected:
            startTrafficPolling()
        case .disconnected, .invalid:
            stopTrafficPolling()
        default:
            break
        }

        let vpnStat = vpnStatus(from: status)

        if vpnStat == lastSentStatus {
            appLog.notice("handleStatusChange: duplicate \(String(describing: vpnStat), privacy: .public) suppressed")
            return
        }
        lastSentStatus = vpnStat

        let msg = VpnStatusMessage(status: vpnStat, connectedAtEpochMs: connectedAtEpochMs())
        eventReceiver.onStatusChanged(message: msg) { _ in }
    }

    private func vpnStatus(from status: NEVPNStatus) -> VpnStatus {
        switch status {
        case .invalid, .disconnected: return .disconnected
        case .connecting, .reasserting: return .connecting
        case .connected: return .connected
        case .disconnecting: return .disconnecting
        @unknown default: return .disconnected
        }
    }

    private func startTrafficPolling() {
        guard trafficTimer == nil else { return }
        pollTraffic()
        pollLogs()
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollTraffic()
            self?.pollLogs()
        }
    }

    private func stopTrafficPolling() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }

    private func pollTraffic() {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected
        else { return }

        let request = Data("traffic".utf8)
        try? session.sendProviderMessage(request) { [weak self] responseData in
            guard let responseData,
                  let traffic = AppMessageWire.decodeTraffic(responseData)
            else { return }

            let msg = VpnTrafficMessage(
                uplinkBytes: traffic.uplink,
                downlinkBytes: traffic.downlink,
                memoryBytes: traffic.memory
            )
            self?.eventReceiver.onTraffic(message: msg) { _ in }
        }
    }

    private func pollLogs() {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected
        else { return }

        let request = Data("logs".utf8)
        try? session.sendProviderMessage(request) { [weak self] responseData in
            guard let self, let responseData else { return }

            for entry in AppMessageWire.decodeLogs(responseData) {
                let msg = VpnLogMessage(
                    level: entry.level,
                    message: entry.message,
                    source: entry.source,
                    timestampMs: entry.timestampMs
                )
                self.eventReceiver.onLog(message: msg) { _ in }
            }
        }
    }
}
