// ImageProcessingViewModelTests.swift — EtchBot
// Tests for DrawingSettings and DrawingRecord models.
// (Full ViewModel tests require UIKit and run on-device; these test pure logic.)

import XCTest
@testable import EtchBotCore

final class ImageProcessingViewModelTests: XCTestCase {

    // MARK: — DrawingSettings

    func testDefaultSettings() {
        let settings = DrawingSettings.defaults
        XCTAssertEqual(settings.pointCount, 2500)
        XCTAssertEqual(settings.contrastMultiplier, 1.0)
        XCTAssertFalse(settings.edgeEmphasisEnabled)
        XCTAssertEqual(settings.edgeWeight, 0.3)
        XCTAssertEqual(settings.voronoiIterations, 40)
        XCTAssertEqual(settings.tspStartingPositions, 8)
    }

    func testEstimatedDrawTimeScalesWithPointCount() {
        var settings = DrawingSettings.defaults
        settings.pointCount = 500
        let lowTime = settings.estimatedDrawTimeMinutes

        settings.pointCount = 5000
        let highTime = settings.estimatedDrawTimeMinutes

        XCTAssertLessThan(lowTime, highTime)
    }

    func testSettingsEquatability() {
        let s1 = DrawingSettings.defaults
        var s2 = DrawingSettings.defaults
        XCTAssertEqual(s1, s2)

        s2.pointCount = 3000
        XCTAssertNotEqual(s1, s2)
    }

    // MARK: — DeviceProfile

    func testDeviceProfileCreation() {
        let profile = DeviceProfile(id: "test-uuid", name: "My EtchBot")
        XCTAssertEqual(profile.id, "test-uuid")
        XCTAssertEqual(profile.name, "My EtchBot")
        XCTAssertFalse(profile.calibration.isCalibrated)
        XCTAssertNil(profile.lastConnected)
    }

    func testDeviceProfileCodable() throws {
        let profile = DeviceProfile(
            id: "abc123",
            name: "Test Bot",
            calibration: CalibrationData(stepsPerMmHorizontal: 42.0, stepsPerMmVertical: 38.0,
                                         backlashHorizontalSteps: 70, backlashVerticalSteps: 50,
                                         drawingSpeedRPM: 80, isCalibrated: true)
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(DeviceProfile.self, from: data)
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.calibration.stepsPerMmHorizontal, 42.0)
        XCTAssertTrue(decoded.calibration.isCalibrated)
    }

    // MARK: — DrawingRecord

    func testDrawingRecordCodable() throws {
        let record = DrawingRecord(
            pointCount: 3000,
            estimatedMinutes: 42,
            deviceName: "My EtchBot"
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(DrawingRecord.self, from: data)
        XCTAssertEqual(decoded.pointCount, 3000)
        XCTAssertEqual(decoded.estimatedMinutes, 42)
        XCTAssertEqual(decoded.deviceName, "My EtchBot")
    }

    // MARK: — CalibrationData

    func testCalibrationDataEquality() {
        let c1 = CalibrationData.defaults
        var c2 = CalibrationData.defaults
        XCTAssertEqual(c1, c2)
        c2.backlashHorizontalSteps = 90
        XCTAssertNotEqual(c1, c2)
    }

    func testCalibrationDataCodable() throws {
        let cal = CalibrationData.defaults
        let data = try JSONEncoder().encode(cal)
        let decoded = try JSONDecoder().decode(CalibrationData.self, from: data)
        XCTAssertEqual(decoded, cal)
    }
}
