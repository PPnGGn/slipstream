import Network
import NetworkExtension
import os

enum TunnelLog {
    static let subsystem = "vpn.oko.XrayTunnel"
    static let lifecycle  = Logger(subsystem: subsystem, category: "lifecycle")
    static let packetFlow = Logger(subsystem: subsystem, category: "packetflow")
    static let core       = Logger(subsystem: subsystem, category: "core")
}

/// Compact binary encoding for the traffic/logs replies sent back over
/// `handleAppMessage`, instead of `JSONSerialization`. This runs on a 1s
/// timer inside the extension's tight (~50MB) memory budget, so avoiding a
/// transient NSDictionary/NSNumber/NSString graph per poll — plus a smaller
/// wire payload — is a straight win, never a cost.
/// Mirrored by the decoder in ios/Runner/VpnConnectionImpl.swift — keep both
/// in sync if the format changes.
enum AppMessageWire {
    /// `[uplink: UInt64 BE][downlink: UInt64 BE]` — 16 bytes, always.
    static func encodeTraffic(uplink: Int64, downlink: Int64) -> Data {
        var w = ByteWriter()
        w.writeUInt64BE(UInt64(bitPattern: uplink))
        w.writeUInt64BE(UInt64(bitPattern: downlink))
        return w.data
    }

    /// `[count: UInt32 BE]`, then per entry:
    /// `[level: UInt8][timestampMs: UInt64 BE][source: UInt16-len-prefixed utf8][message: UInt32-len-prefixed utf8]`.
    static func encodeLogs(_ entries: [CoreLogBridge.Entry]) -> Data {
        var w = ByteWriter()
        w.writeUInt32BE(UInt32(entries.count))
        for e in entries {
            w.writeUInt8(levelCode(e.level))
            w.writeUInt64BE(UInt64(bitPattern: e.timestampMs))
            w.writeString16(e.source)
            w.writeString32(e.message)
        }
        return w.data
    }

    // Canonicalizes zap's ("warn", "fatal", "panic") and xray's own severity
    // names down to the 4 levels the Flutter side actually distinguishes —
    // same grouping TunnelLog's own routing above already uses.
    private static func levelCode(_ level: String) -> UInt8 {
        switch level {
        case "debug": return 0
        case "warning", "warn": return 2
        case "error", "fatal", "panic": return 3
        default: return 1 // info
        }
    }
}

/// Minimal big-endian byte writer backing [AppMessageWire]'s encoders.
private struct ByteWriter {
    private(set) var data = Data()

    mutating func writeUInt8(_ v: UInt8) { data.append(v) }

    mutating func writeUInt16BE(_ v: UInt16) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeUInt32BE(_ v: UInt32) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeUInt64BE(_ v: UInt64) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeString16(_ s: String) {
        let bytes = Array(s.utf8.prefix(Int(UInt16.max)))
        writeUInt16BE(UInt16(bytes.count))
        data.append(contentsOf: bytes)
    }

    mutating func writeString32(_ s: String) {
        let bytes = Array(s.utf8.prefix(Int(UInt32.max)))
        writeUInt32BE(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }
}


final class CoreLogBridge: NSObject, IosHandlerProtocol {
    struct Entry {
        let level: String
        let message: String
        let source: String
        let timestampMs: Int64
    }

    private let lock = NSLock()
    private var buffer: [Entry] = []
    private static let maxBuffered = 2000

    func onLog(_ level: String?, message: String?, source: String?) {
        let lvl = (level ?? "info").lowercased()
        let src = source ?? "core"
        let msg = message ?? ""

        switch lvl {
        case "debug":
            TunnelLog.core.debug("[\(src, privacy: .public)] \(msg, privacy: .public)")
        case "warning", "warn":
            TunnelLog.core.warning("[\(src, privacy: .public)] \(msg, privacy: .public)")
        case "error", "fatal", "panic":
            TunnelLog.core.error("[\(src, privacy: .public)] \(msg, privacy: .public)")
        default:
            TunnelLog.core.info("[\(src, privacy: .public)] \(msg, privacy: .public)")
        }

        let entry = Entry(
            level: lvl,
            message: msg,
            source: src,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        lock.lock()
        buffer.append(entry)
        if buffer.count > Self.maxBuffered {
            buffer.removeFirst(buffer.count - Self.maxBuffered)
        }
        lock.unlock()
    }

    func drain() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        let out = buffer
        buffer.removeAll(keepingCapacity: true)
        return out
    }
}

final class PacketFlowBridge: NSObject, IosPacketFlowProtocol {
    private let flow: NEPacketTunnelFlow
    private let queue = DispatchQueue(label: "vpn.oko.xraytunnel.read")
    private let semaphore = DispatchSemaphore(value: 0)
    private var buffer: [Data] = []
    private let bufferLock = NSLock()
    private var closed = false

    private var pumpCallbackCount = 0
    private var readCount = 0
    private var writeCount = 0

    init(flow: NEPacketTunnelFlow) {
        self.flow = flow
        super.init()
        TunnelLog.packetFlow.notice("PacketFlowBridge: init; pump started")
        pump()
    }

    private func pump() {
        flow.readPackets { [weak self] packets, _ in
            guard let self, !self.closed else { return }
            self.bufferLock.lock()
            self.pumpCallbackCount += 1
            let firstCallback = self.pumpCallbackCount == 1
            let bufferDepth = self.buffer.count + packets.count
            self.buffer.append(contentsOf: packets)
            self.bufferLock.unlock()
            if firstCallback {
                TunnelLog.packetFlow.notice("pump: FIRST readPackets callback; \(packets.count, privacy: .public) pkts (device is producing outbound traffic)")
            }
            if bufferDepth > 1000 && bufferDepth % 1000 == 0 {
                TunnelLog.packetFlow.error("pump: buffer backlog=\(bufferDepth, privacy: .public) — netstack not draining readPacket()")
            }
            for _ in packets {
                self.semaphore.signal()
            }
            self.pump()
        }
    }

    func close() {
        TunnelLog.packetFlow.notice("close: called (closed=true, signaling semaphore)")
        closed = true
        semaphore.signal()
    }

    func readPacket() throws -> Data {
        semaphore.wait()
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard !buffer.isEmpty else {
            TunnelLog.packetFlow.notice("readPacket: buffer empty after signal → throwing 'flow closed' (returns EOF to Go, dispatchLoop will exit)")
            throw NSError(domain: "vpn.oko.XrayTunnel", code: 3, userInfo: [NSLocalizedDescriptionKey: "flow closed"])
        }
        readCount += 1
        if readCount == 1 {
            TunnelLog.packetFlow.notice("readPacket: FIRST packet delivered to netstack")
        } else if readCount % 500 == 0 {
            TunnelLog.packetFlow.info("readPacket: \(self.readCount, privacy: .public) packets device→netstack")
        }
        return buffer.removeFirst()
    }

    func writePacket(_ packet: Data?) throws {
        guard let packet else {
            TunnelLog.packetFlow.debug("writePacket: nil packet ignored")
            return
        }
        bufferLock.lock()
        writeCount += 1
        let count = writeCount
        bufferLock.unlock()
        if count == 1 {
            TunnelLog.packetFlow.notice("writePacket: FIRST return packet netstack→device (\(packet.count, privacy: .public) bytes) — data path is bidirectional")
        } else if count % 500 == 0 {
            TunnelLog.packetFlow.info("writePacket: \(count, privacy: .public) packets netstack→device")
        }
        let family: NSNumber = (packet.first.map { $0 >> 4 } == 6) ? AF_INET6 as NSNumber : AF_INET as NSNumber
        flow.writePackets([packet], withProtocols: [family])
    }
}

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var flowBridge: PacketFlowBridge?
    private let logBridge = CoreLogBridge()
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "vpn.oko.xraytunnel.path")

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        IosSetHandler(logBridge)
        TunnelLog.lifecycle.notice("startTunnel: entry; options keys=\(options?.keys.map(String.init(describing:)).joined(separator: ",") ?? "nil", privacy: .public)")

        let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        let configJson = (options?["configJson"] as? String) ?? (providerConfig?["configJson"] as? String)
        let socksPort = (options?["socksPort"] as? NSNumber)
            ?? (providerConfig?["socksPort"] as? NSNumber)
            ?? (providerConfig?["socksPort"] as? Int).map(NSNumber.init(value:))
      
        let geoAssetDir = (options?["geoAssetDir"] as? String) ?? (providerConfig?["geoAssetDir"] as? String) ?? ""

        guard let configJson, let socksPort else {
            TunnelLog.lifecycle.error("startTunnel: missing configJson/socksPort in both options and providerConfiguration; aborting")
            completionHandler(NSError(
                domain: "vpn.oko.XrayTunnel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing configJson/socksPort in tunnel options"]
            ))
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.ipv4Settings = NEIPv4Settings(addresses: ["10.10.10.2"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        settings.ipv6Settings = NEIPv6Settings(addresses: ["fd00:10:10:10::2"], networkPrefixLengths: [64])
        settings.ipv6Settings?.includedRoutes = [NEIPv6Route.default()]
        settings.mtu = 1500
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])

        TunnelLog.lifecycle.notice("startTunnel: applying network settings (tunnel 10.10.10.2/24 + fd00:10:10:10::2/64, dns 1.1.1.1, mtu 1500)")
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                TunnelLog.lifecycle.error("setTunnelNetworkSettings FAILED: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
                return
            }
            TunnelLog.lifecycle.notice("setTunnelNetworkSettings OK")

            let bridge = PacketFlowBridge(flow: self.packetFlow)
            self.flowBridge = bridge

            var startError: NSError?
            let ok = IosStart(configJson, bridge, socksPort.intValue, geoAssetDir, &startError)
            TunnelLog.lifecycle.notice("IosStart(socksPort=\(socksPort.intValue, privacy: .public), configLen=\(configJson.count, privacy: .public), geoAssetDir=\(geoAssetDir.isEmpty ? "<default>" : geoAssetDir, privacy: .public)) -> ok=\(ok, privacy: .public)")
            if !ok {
                TunnelLog.lifecycle.error("IosStart FAILED: \(startError?.localizedDescription ?? "unknown", privacy: .public)")
                completionHandler(startError ?? NSError(
                    domain: "vpn.oko.XrayTunnel",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "IosStart failed"]
                ))
                return
            }

            TunnelLog.lifecycle.notice("startTunnel: completed successfully; tunnel is up")
            self.startPathMonitor()
            withTimeout(2, { done in self.enableOnDemand(completion: done) }) {
                completionHandler(nil)
            }
        }
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { path in
            let ifaces = path.availableInterfaces.map { "\($0.type)" }.joined(separator: ",")
            TunnelLog.lifecycle.notice(
                "path change: status=\(String(describing: path.status), privacy: .public) ifaces=\(ifaces, privacy: .public) expensive=\(path.isExpensive, privacy: .public)")
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        TunnelLog.lifecycle.notice("stopTunnel: reason=\(reason.rawValue, privacy: .public)")

        pathMonitor.cancel()
        flowBridge?.close()
        flowBridge = nil
        TunnelLog.lifecycle.notice("stopTunnel: flow bridge closed")

        let finishStop = {
            DispatchQueue.global(qos: .userInitiated).async {
                var stopError: NSError?
                _ = IosStop(&stopError)
                TunnelLog.lifecycle.notice("stopTunnel: IosStop returned; stopError=\(stopError?.localizedDescription ?? "nil", privacy: .public)")
                IosSetHandler(nil)
                completionHandler()
            }
        }

        guard reason == .userInitiated else {
            finishStop()
            return
        }
      withTimeout(2, { done in self.disableOnDemand(completion: done) }, then: finishStop)
    }

   
    private func withTimeout(
        _ seconds: TimeInterval,
        _ work: (@escaping () -> Void) -> Void,
        then completion: @escaping () -> Void
    ) {
        let lock = NSLock()
        var didComplete = false
        let completeOnce = {
            lock.lock()
            let already = didComplete
            didComplete = true
            lock.unlock()
            if !already { completion() }
        }
        work(completeOnce)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds) {
            completeOnce()
        }
    }

    private func disableOnDemand(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let manager = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Bundle.main.bundleIdentifier
            }), manager.isOnDemandEnabled else {
                completion()
                return
            }
            manager.isOnDemandEnabled = false
            manager.saveToPreferences { error in
                if let error {
                    TunnelLog.lifecycle.error("disableOnDemand: save failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    TunnelLog.lifecycle.notice("disableOnDemand: on-demand disabled (userInitiated stop)")
                }
                completion()
            }
        }
    }

    private func enableOnDemand(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let manager = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Bundle.main.bundleIdentifier
            }) else {
                completion()
                return
            }
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            guard !manager.isOnDemandEnabled else {
                completion()
                return
            }
            manager.isOnDemandEnabled = true
            manager.saveToPreferences { error in
                if let error {
                    TunnelLog.lifecycle.error("enableOnDemand: save failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    TunnelLog.lifecycle.notice("enableOnDemand: on-demand re-armed after successful start")
                }
                completion()
            }
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        switch String(data: messageData, encoding: .utf8) {
        case "traffic":
            let stats = IosQueryTraffic()
            TunnelLog.packetFlow.debug("traffic query: up=\(stats?.uplinkBytes ?? 0, privacy: .public) down=\(stats?.downlinkBytes ?? 0, privacy: .public)")
            completionHandler?(AppMessageWire.encodeTraffic(
                uplink: stats?.uplinkBytes ?? 0,
                downlink: stats?.downlinkBytes ?? 0
            ))
        case "logs":
            completionHandler?(AppMessageWire.encodeLogs(logBridge.drain()))
        default:
            completionHandler?(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        TunnelLog.lifecycle.notice("sleep: device sleeping; freeing memory")
        IosFreeMemory()
        completionHandler()
    }

    override func wake() {
        TunnelLog.lifecycle.notice("wake: device woke")
    }
}
