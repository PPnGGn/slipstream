import Darwin
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
    /// `[uplink: UInt64 BE][downlink: UInt64 BE][memory: UInt64 BE]` — 24
    /// bytes, always.
    static func encodeTraffic(uplink: Int64, downlink: Int64, memory: Int64) -> Data {
        var w = ByteWriter()
        w.writeUInt64BE(UInt64(bitPattern: uplink))
        w.writeUInt64BE(UInt64(bitPattern: downlink))
        w.writeUInt64BE(UInt64(bitPattern: memory))
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

/// `phys_footprint` from `TASK_VM_INFO` — the exact figure jetsam charges
/// this extension against its ~50MB budget (unlike `resident_size`, which
/// undercounts compressed memory and so under-warns right up to the kill).
private func currentFootprintBytes() -> Int64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let kerr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kerr == KERN_SUCCESS ? Int64(info.phys_footprint) : 0
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
    #if DEBUG
    private var memorySampler: MemorySampler?
    #endif

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        IosSetHandler(logBridge)
        #if DEBUG
        // Chatty core logs (xray access + DNS, tun2socks connections) for debug
        // builds only; the build itself decides, so release never turns them on.
        IosSetVerboseLogs(true)
        // Memory samples and the command file, see MemorySampler. Started before
        // the core so that the peak of building a large config is in them.
        memorySampler = MemorySampler()
        memorySampler?.start()
        #endif
        TunnelLog.lifecycle.notice("startTunnel: core is xray \(IosVersion(), privacy: .public)")
        TunnelLog.lifecycle.notice("startTunnel: entry; options keys=\(options?.keys.map(String.init(describing:)).joined(separator: ",") ?? "nil", privacy: .public)")

        let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        let configJson = (options?["configJson"] as? String) ?? (providerConfig?["configJson"] as? String)
        let geoAssetDir = (options?["geoAssetDir"] as? String) ?? (providerConfig?["geoAssetDir"] as? String) ?? ""

        guard let configJson else {
            TunnelLog.lifecycle.error("startTunnel: missing configJson in both options and providerConfiguration; aborting")
            completionHandler(NSError(
                domain: "vpn.oko.XrayTunnel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing configJson in tunnel options"]
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
            // The core picks the SOCKS port and credentials itself; they never leave Go.
            let ok = IosStart(configJson, bridge, geoAssetDir, &startError)
            TunnelLog.lifecycle.notice("IosStart(configLen=\(configJson.count, privacy: .public), geoAssetDir=\(geoAssetDir.isEmpty ? "<default>" : geoAssetDir, privacy: .public)) -> ok=\(ok, privacy: .public)")
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
                #if DEBUG
                self.memorySampler?.stop()
                self.memorySampler = nil
                #endif
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
            // goRetained is what the Go runtime holds from the OS, footprint what the
            // system charges the whole extension (and enforces its limit on).
            let goMemory = IosQueryMemory()
            TunnelLog.packetFlow.debug("traffic query: up=\(stats?.uplinkBytes ?? 0, privacy: .public) down=\(stats?.downlinkBytes ?? 0, privacy: .public) goRetained=\(goMemory?.retainedBytes ?? 0, privacy: .public) footprint=\(currentFootprintBytes(), privacy: .public)")
            completionHandler?(AppMessageWire.encodeTraffic(
                uplink: stats?.uplinkBytes ?? 0,
                downlink: stats?.downlinkBytes ?? 0,
                memory: currentFootprintBytes()
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

#if DEBUG
/// Debug builds only. Measures the extension on a device without Xcode attached:
/// once a second it appends one JSON line of memory figures to a file in the app
/// group, and it runs the commands found in a command file in the same folder.
/// Both files are reached from the Mac with
/// `xcrun devicectl device copy from|to --domain-type appGroupDataContainer`.
///
/// Folder `Library/memsample/` of the app group:
///   samples.jsonl  one line per second, plus an event line per command
///   command.txt    commands, one per line; deleted once they have run:
///                    label <text>            tag the samples that follow
///                    gc <percent> <limitMB>  GC settings of the core (0 = no limit)
///                    udp <seconds>           idle time of a UDP session (60 by default)
///                    heap <name>             write heap-<name>.pprof here
///                    goroutines <name>       write goroutines-<name>.txt here
///                    free                    run a GC and hand memory back
///                    truncate                start samples.jsonl over
///
/// Sample fields, bytes: footprint (what jetsam charges), peak (the highest it
/// has been), available (os_proc_available_memory: how much more the extension
/// may take, so footprint + available is the limit), and the Go runtime's
/// share (retained, total, heap, stack), goroutines, gc cycles, gcPercent and
/// limitMB (-1 = none).
final class MemorySampler {
    static let groupID = "group.vpn.oko"

    private let queue = DispatchQueue(label: "vpn.oko.xraytunnel.memsampler", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let dir: URL
    private var samplesURL: URL { dir.appendingPathComponent("samples.jsonl") }
    private var commandURL: URL { dir.appendingPathComponent("command.txt") }
    private var label = "start"

    init?() {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID) else {
            TunnelLog.lifecycle.error("MemorySampler: no app group container for \(Self.groupID, privacy: .public)")
            return nil
        }
        // Under Library: devicectl reaches only Library, Documents and tmp of a container.
        dir = base.appendingPathComponent("Library/memsample", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func start() {
        queue.async {
            self.append(#"{"event":"sampler-start","t":\#(Self.nowMs())}"#)
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async {
            self.append(#"{"event":"sampler-stop","t":\#(Self.nowMs())}"#)
        }
    }

    private func tick() {
        runCommands()
        append(sampleLine())
    }

    private func sampleLine() -> String {
        let footprint = currentFootprintBytes()
        let go = IosQueryMemory()
        let limit = go?.memoryLimitBytes ?? Int64.max
        let limitMB = limit == Int64.max ? -1 : limit >> 20
        return #"{"t":\#(Self.nowMs()),"label":"\#(Self.escape(label))","footprint":\#(footprint),"peak":\#(footprintPeakBytes()),"available":\#(os_proc_available_memory()),"goRetained":\#(go?.retainedBytes ?? 0),"goTotal":\#(go?.totalBytes ?? 0),"goHeap":\#(go?.heapInuseBytes ?? 0),"goStack":\#(go?.stackBytes ?? 0),"goroutines":\#(go?.goroutines ?? 0),"gcCycles":\#(go?.gcCycles ?? 0),"gcPercent":\#(go?.gcPercent ?? 0),"limitMB":\#(limitMB)}"#
    }

    private func runCommands() {
        guard let text = try? String(contentsOf: commandURL, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: commandURL)
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            var error: NSError?
            var detail = ""
            var ok = true
            switch parts[0] {
            case "label" where parts.count >= 2:
                label = parts.dropFirst().joined(separator: " ")
            case "gc" where parts.count == 3:
                ok = IosSetGCTuning(Int(parts[1]) ?? 0, Int(parts[2]) ?? 0, &error)
            case "udp" where parts.count == 2:
                ok = IosSetUDPTimeout(Int(parts[1]) ?? 0, &error)
            case "heap" where parts.count == 2:
                detail = IosWriteHeapProfile(dir.path, parts[1], &error)
                ok = error == nil
            case "goroutines" where parts.count == 2:
                detail = IosWriteGoroutineDump(dir.path, parts[1], &error)
                ok = error == nil
            case "free":
                IosFreeMemory()
            case "truncate":
                try? FileManager.default.removeItem(at: samplesURL)
            default:
                ok = false
                detail = "unknown command"
            }
            if let error { detail = error.localizedDescription }
            append(#"{"event":"cmd","t":\#(Self.nowMs()),"cmd":"\#(Self.escape(line))","ok":\#(ok),"detail":"\#(Self.escape(detail))"}"#)
        }
    }

    private func append(_ line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: samplesURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: samplesURL)
        }
    }

    private static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// The highest `phys_footprint` the extension has reached, which one-second
/// samples can miss (the start of a session, building the geo matchers, is a
/// peak a few hundred milliseconds wide).
private func footprintPeakBytes() -> Int64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let kerr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kerr == KERN_SUCCESS ? info.ledger_phys_footprint_peak : 0
}
#endif
