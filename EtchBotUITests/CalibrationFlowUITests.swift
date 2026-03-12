// CalibrationFlowUITests.swift — EtchBot
// UI tests for the device pairing and calibration wizard flow.

import XCTest

final class CalibrationFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    // TC-003 / TC-005: BLE permission — device list presents without crash
    func testDeviceListOpens() {
        _ = app.staticTexts["EtchBot"].waitForExistence(timeout: 5)

        let deviceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'No device'")).firstMatch
        if deviceButton.exists {
            deviceButton.tap()
            // Devices sheet should appear
            let devicesTitle = app.navigationBars["Devices"]
            XCTAssertTrue(devicesTitle.waitForExistence(timeout: 5))

            // Close it
            let doneButton = app.buttons["Done"]
            if doneButton.exists { doneButton.tap() }
        }
    }

    // TC-005: App works without Bluetooth (shows "No device connected")
    func testAppFunctionsWithoutBluetooth() {
        XCTAssertTrue(app.state == .runningForeground)
        // Home screen should show even without BLE
        XCTAssertTrue(app.staticTexts["EtchBot"].waitForExistence(timeout: 5))
    }
}
