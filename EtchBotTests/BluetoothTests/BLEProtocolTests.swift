// BLEProtocolTests.swift — EtchBot
// Tests for BLE protocol data structures (no hardware required).

import XCTest
@testable import EtchBotCore

final class BLEProtocolTests: XCTestCase {

    // MARK: — DeviceStatus parsing

    func testDeviceStatusParseValidData() {
        // state=Drawing(2), current=500, total=1000, error=0, power=1
        let data = Data([
            0x02,           // state: drawing
            0xF4, 0x01,    // currentMoveIndex = 500 LE
            0xE8, 0x03,    // totalMoves = 1000 LE
            0x00,           // errorCode
            0x01            // powerStatus
        ])
        let status = DeviceStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.state, .drawing)
        XCTAssertEqual(status?.currentMoveIndex, 500)
        XCTAssertEqual(status?.totalMoves, 1000)
        XCTAssertEqual(status?.progressFraction, 0.5, accuracy: 0.001)
    }

    func testDeviceStatusTooShortDataReturnsNil() {
        let data = Data([0x02, 0x00])
        XCTAssertNil(DeviceStatus(data: data))
    }

    func testDeviceStatusAllStates() {
        let states: [(UInt8, DeviceState)] = [
            (0, .idle), (1, .receiving), (2, .drawing), (3, .paused),
            (4, .complete), (5, .error), (6, .homing), (7, .calibrating)
        ]
        for (raw, expected) in states {
            let data = Data([raw, 0, 0, 0, 0, 0, 0])
            let status = DeviceStatus(data: data)
            XCTAssertEqual(status?.state, expected, "State \(raw) should map to \(expected)")
        }
    }

    // MARK: — TransferStatus parsing

    func testTransferStatusParsing() {
        let data = Data([0x05, 0xB8, 0x0B, 0x01])  // 5 chunks, 3000 bytes, ready=true
        let status = TransferStatus(data: data)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.chunksReceived, 5)
        XCTAssertEqual(status?.bytesReceived, 3000)
        XCTAssertEqual(status?.readyForNextChunk, true)
    }

    func testTransferStatusNotReady() {
        let data = Data([0x01, 0x00, 0x01, 0x00])  // ready=false
        let status = TransferStatus(data: data)
        XCTAssertEqual(status?.readyForNextChunk, false)
    }

    // MARK: — CalibrationData wire format round-trip

    func testCalibrationDataRoundTrip() {
        let original = CalibrationData(
            stepsPerMmHorizontal: 42.5,
            stepsPerMmVertical: 38.0,
            backlashHorizontalSteps: 75,
            backlashVerticalSteps: 55,
            homeOffsetX: 10,
            homeOffsetY: 5,
            drawingSpeedRPM: 120,
            isCalibrated: true
        )
        let wireData = original.toWireFormat()
        XCTAssertEqual(wireData.count, 12)

        let decoded = CalibrationData.fromWireFormat(wireData)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.stepsPerMmHorizontal ?? 0, 42.5, accuracy: 0.1)
        XCTAssertEqual(decoded?.stepsPerMmVertical ?? 0, 38.0, accuracy: 0.1)
        XCTAssertEqual(decoded?.backlashHorizontalSteps, 75)
        XCTAssertEqual(decoded?.backlashVerticalSteps, 55)
        XCTAssertEqual(decoded?.drawingSpeedRPM, 120)
    }

    func testCalibrationDataDefaultsAreReasonable() {
        let cal = CalibrationData.defaults
        XCTAssertEqual(cal.stepsPerMmHorizontal, 40.0)
        XCTAssertEqual(cal.stepsPerMmVertical, 40.0)
        XCTAssertEqual(cal.backlashHorizontalSteps, 60)
        XCTAssertEqual(cal.backlashVerticalSteps, 60)
        XCTAssertFalse(cal.isCalibrated)
    }

    // MARK: — TransferCommand raw values

    func testTransferCommandRawValues() {
        XCTAssertEqual(TransferCommand.startTransfer.rawValue, 0x01)
        XCTAssertEqual(TransferCommand.endTransfer.rawValue, 0x02)
        XCTAssertEqual(TransferCommand.startDrawing.rawValue, 0x10)
        XCTAssertEqual(TransferCommand.pause.rawValue, 0x11)
        XCTAssertEqual(TransferCommand.resume.rawValue, 0x12)
        XCTAssertEqual(TransferCommand.cancel.rawValue, 0x13)
        XCTAssertEqual(TransferCommand.home.rawValue, 0x20)
    }
}
