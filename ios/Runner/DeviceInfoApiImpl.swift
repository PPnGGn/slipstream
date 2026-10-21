import UIKit

// Thin on purpose: only reads raw values. Hashing and fallbacks live in Dart.
final class DeviceInfoApiImpl: DeviceInfoApi {
    func getDeviceInfo() throws -> DeviceInfoMessage {
        let device = UIDevice.current
        return DeviceInfoMessage(
            // Nil right after a reboot until the first unlock; Dart handles null.
            deviceId: device.identifierForVendor?.uuidString,
            os: "iOS",
            osVersion: device.systemVersion,
            model: DeviceInfoApiImpl.machineIdentifier()
        )
    }

    // UIDevice.model is always just "iPhone", so read the hardware identifier.
    private static func machineIdentifier() -> String {
        // On the simulator utsname reports "arm64", not a model.
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return sim
        }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
