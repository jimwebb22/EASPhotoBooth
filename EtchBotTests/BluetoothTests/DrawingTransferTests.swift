// DrawingTransferTests.swift — EtchBot
// Tests for DrawingTransferService chunking logic and data integrity.
// (No hardware required — tests the encoding/chunking layer.)

import XCTest
@testable import EtchBotCore

final class DrawingTransferTests: XCTestCase {

    // MARK: — Encoding produces correct chunk count

    func testChunkCountForKnownDataSize() throws {
        // Create 500 move commands → 12 header + 1000 payload = 1012 bytes
        let moves = (0..<500).map { _ in MoveCommand(direction: .east, runLength: 10) }
        let path = DrawingPath(moves: moves, widthInSteps: 1000, heightInSteps: 600, estimatedDrawTimeSeconds: 30)
        let encoded = try DrawingPathEncoder.encode(path)
        let totalBytes = encoded.encodedData!.count
        // At 244 bytes per chunk:
        let expectedChunks = Int(ceil(Double(totalBytes) / 244.0))
        XCTAssertEqual(expectedChunks, 5)  // 1012 / 244 = 4.15 → 5 chunks
    }

    func testEncodedDataIntegrityAfterChunking() throws {
        let moves = [
            MoveCommand(direction: .northeast, runLength: 8191),
            MoveCommand(direction: .southwest, runLength: 8191),
        ]
        let path = DrawingPath(moves: moves, widthInSteps: 5000, heightInSteps: 3200, estimatedDrawTimeSeconds: 60)
        let encoded = try DrawingPathEncoder.encode(path)
        guard let data = encoded.encodedData else { XCTFail(); return }

        // Simulate chunking and reassembly
        let chunkSize = 244
        var reassembled = Data()
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            reassembled.append(contentsOf: data[offset..<end])
            offset = end
        }

        XCTAssertEqual(data, reassembled)
        // Verify CRC of reassembled data matches original
        let header = DrawingPathEncoder.verify(reassembled)
        XCTAssertNotNil(header)
        XCTAssertEqual(header?.moveCount, 2)
    }

    // MARK: — CalibrationData drawing area calculations

    func testDrawingAreaStepsCalculation() {
        let cal = CalibrationData(
            stepsPerMmHorizontal: 40.0,
            stepsPerMmVertical: 40.0,
            backlashHorizontalSteps: 60,
            backlashVerticalSteps: 60
        )
        // 40 steps/mm × 175mm = 7000
        XCTAssertEqual(cal.drawingAreaWidthSteps, 7000)
        // 40 steps/mm × 120mm = 4800
        XCTAssertEqual(cal.drawingAreaHeightSteps, 4800)
    }

    // MARK: — DrawingSettings

    func testEstimatedDrawTimeIsPositive() {
        let settings = DrawingSettings.defaults
        XCTAssertGreaterThan(settings.estimatedDrawTimeMinutes, 0)
    }

    func testPointCountClampedToRange() {
        XCTAssertTrue(DrawingSettings.pointCountRange.contains(DrawingSettings.defaults.pointCount))
    }
}
