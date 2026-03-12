// DrawingFlowUITests.swift — EtchBot
// UI tests for the drawing editor and preview flow.

import XCTest

final class DrawingFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    // TC-007: App does not crash on home screen
    func testHomeScreenStable() {
        XCTAssertTrue(app.state == .runningForeground)
        // Allow the home screen to render fully
        _ = app.staticTexts["EtchBot"].waitForExistence(timeout: 5)
        XCTAssertEqual(app.state, .runningForeground)
    }

    // TC-012: Basic orientation support check
    func testHomeScreenRotatesToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["EtchBot"].waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .portrait
    }

    // Device status row appears
    func testDeviceStatusRowVisible() {
        let statusRow = app.buttons.matching(identifier: "No device connected. Tap to open device list.").firstMatch
        XCTAssertTrue(statusRow.waitForExistence(timeout: 5))
    }
}
