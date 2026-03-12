// CameraFlowUITests.swift — EtchBot
// UI tests for the camera capture flow.
// Run on iOS Simulator (camera unavailable in simulator — tests photo library path).

import XCTest

final class CameraFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    // TC-007: App launches and displays home screen
    func testAppLaunchesWithoutCrash() {
        XCTAssertTrue(app.state == .runningForeground)
    }

    // TC-007: Home screen renders
    func testHomeScreenDisplaysFrame() {
        // The Etch-a-Sketch frame title "EtchBot" should be visible
        let title = app.staticTexts["EtchBot"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    // Camera button exists
    func testTakePhotoButtonExists() {
        let button = app.buttons["Take Photo"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    // Choose Photo button exists
    func testChoosePhotoButtonExists() {
        let button = app.buttons["Choose Photo"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    // TC-009: No device — send button should be absent or disabled on home screen
    func testSendButtonNotVisibleWithoutDevice() {
        // "Send to EtchBot" only appears after selecting a photo and navigating to editor
        let sendButton = app.buttons["Send to EtchBot"]
        // Should not exist on home screen
        XCTAssertFalse(sendButton.exists)
    }

    // Device pairing entry point exists
    func testDeviceListButtonExists() {
        // The antenna icon in the toolbar
        let deviceButton = app.buttons["Connect device"]
        XCTAssertTrue(deviceButton.waitForExistence(timeout: 5))
    }
}
