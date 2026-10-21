import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testDeviceInfoReportsIosAndSystemVersion() throws {
    let info = try DeviceInfoApiImpl().getDeviceInfo()

    XCTAssertEqual(info.os, "iOS")
    XCTAssertEqual(info.osVersion, UIDevice.current.systemVersion)
  }

  // UIDevice.model is just "iPhone" and utsname on the simulator is "arm64":
  // neither identifies a device model on the panel.
  func testDeviceInfoModelIsHardwareIdentifier() throws {
    let model = try DeviceInfoApiImpl().getDeviceInfo().model

    XCTAssertFalse(model.isEmpty)
    XCTAssertFalse(["iPhone", "iPad", "arm64", "x86_64"].contains(model))
  }

  // Null is allowed (right after a reboot), garbage is not: Dart hashes it.
  func testDeviceInfoDeviceIdIsUuidWhenPresent() throws {
    let deviceId = try DeviceInfoApiImpl().getDeviceInfo().deviceId

    if let deviceId = deviceId {
      XCTAssertNotNil(UUID(uuidString: deviceId))
    }
  }

}
