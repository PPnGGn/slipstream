import Flutter
import NetworkExtension
import os

private let appLog = Logger(subsystem: "vpn.oko", category: "vpnstatus")

final class VpnConnectionImpl: NSObject, VpnConnection {

    private static let extensionBundleID = "vpn.oko.XrayTunnel"
    private static let socksPort = 10808

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
            proto.providerConfiguration = [
                "configJson": config.configJson,
                "socksPort": Self.socksPort,
            ]
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
                    let options: [String: NSObject] = [
                        "configJson": config.configJson as NSObject,
                        "socksPort": NSNumber(value: Self.socksPort),
                    ]
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
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let uplink = json["uplink"] as? Int64,
                  let downlink = json["downlink"] as? Int64
            else { return }

            let msg = VpnTrafficMessage(uplinkBytes: uplink, downlinkBytes: downlink)
            self?.eventReceiver.onTraffic(message: msg) { _ in }
        }
    }

    private func pollLogs() {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected
        else { return }

        let request = Data("logs".utf8)
        try? session.sendProviderMessage(request) { [weak self] responseData in
            guard let self,
                  let responseData,
                  let entries = try? JSONSerialization.jsonObject(with: responseData) as? [[String: Any]]
            else { return }

            for entry in entries {
                let msg = VpnLogMessage(
                    level: entry["level"] as? String ?? "info",
                    message: entry["message"] as? String ?? "",
                    source: entry["source"] as? String ?? "core",
                    timestampMs: (entry["timestampMs"] as? NSNumber)?.int64Value ?? 0
                )
                self.eventReceiver.onLog(message: msg) { _ in }
            }
        }
    }
}
