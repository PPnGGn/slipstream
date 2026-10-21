import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var vpnConnection: VpnConnectionImpl?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        guard let messenger = engineBridge.pluginRegistry
            .registrar(forPlugin: "VpnConnectionPlugin")?.messenger()
        else { return }
        let conn = VpnConnectionImpl(binaryMessenger: messenger)
        vpnConnection = conn
        VpnConnectionSetup.setUp(binaryMessenger: messenger, api: conn)
        DeviceInfoApiSetup.setUp(binaryMessenger: messenger, api: DeviceInfoApiImpl())
    }
}
