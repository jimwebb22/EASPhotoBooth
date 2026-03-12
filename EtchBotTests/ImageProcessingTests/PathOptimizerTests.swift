// PathOptimizerTests.swift — EtchBot
// Tests for DrawingPathEncoder encode/decode round-trip and move commands.

import XCTest
@testable import EtchBotCore

final class PathOptimizerTests: XCTestCase {

    // MARK: — MoveCommand tests

    func testMoveCommandDirectionEncoding() {
        for dir in StepDirection.allCases {
            let move = MoveCommand(direction: dir, runLength: 100)
            XCTAssertEqual(move.direction, dir)
            XCTAssertEqual(move.runLength, 100)
        }
    }

    func testStepDirectionDeltas() {
        XCTAssertEqual(StepDirection.east.dx, 1);   XCTAssertEqual(StepDirection.east.dy, 0)
        XCTAssertEqual(StepDirection.north.dx, 0);  XCTAssertEqual(StepDirection.north.dy, 1)
        XCTAssertEqual(StepDirection.west.dx, -1);  XCTAssertEqual(StepDirection.west.dy, 0)
        XCTAssertEqual(StepDirection.south.dx, 0);  XCTAssertEqual(StepDirection.south.dy, -1)
        XCTAssertEqual(StepDirection.northeast.dx, 1); XCTAssertEqual(StepDirection.northeast.dy, 1)
        XCTAssertEqual(StepDirection.southwest.dx, -1); XCTAssertEqual(StepDirection.southwest.dy, -1)
    }

    // MARK: — DrawingPathEncoder tests

    func testEncoderRoundTrip() throws {
        let moves = [
            MoveCommand(direction: .east, runLength: 100),
            MoveCommand(direction: .north, runLength: 50),
            MoveCommand(direction: .west, runLength: 100),
            MoveCommand(direction: .south, runLength: 50),
        ]
        let path = DrawingPath(moves: moves, widthInSteps: 7000, heightInSteps: 4800, estimatedDrawTimeSeconds: 120)
        let encoded = try DrawingPathEncoder.encode(path)
        guard let data = encoded.encodedData else {
            XCTFail("encodedData should not be nil"); return
        }
        // Verify header
        let header = DrawingPathEncoder.verify(data)
        XCTAssertNotNil(header)
        XCTAssertEqual(header?.moveCount, 4)
        XCTAssertEqual(header?.widthSteps, 7000)
        XCTAssertEqual(header?.heightSteps, 4800)
        XCTAssertEqual(header?.estimatedSeconds, 120)
    }

    func testEncoderDataSize() throws {
        let moves = (0..<100).map { _ in MoveCommand(direction: .east, runLength: 1) }
        let path = DrawingPath(moves: moves, widthInSteps: 1000, heightInSteps: 1000, estimatedDrawTimeSeconds: 10)
        let encoded = try DrawingPathEncoder.encode(path)
        let data = encoded.encodedData!
        // Header = 12 bytes, each move = 2 bytes
        XCTAssertEqual(data.count, 12 + 100 * 2)
    }

    func testEncoderMaxRunLength() throws {
        let moves = [MoveCommand(direction: .east, runLength: 8191)]
        let path = DrawingPath(moves: moves, widthInSteps: 1000, heightInSteps: 1000, estimatedDrawTimeSeconds: 1)
        let encoded = try DrawingPathEncoder.encode(path)
        XCTAssertNotNil(encoded.encodedData)
        let header = DrawingPathEncoder.verify(encoded.encodedData!)
        XCTAssertNotNil(header)
    }

    func testEncoderEmptyPathThrows() {
        let path = DrawingPath(moves: [], widthInSteps: 0, heightInSteps: 0, estimatedDrawTimeSeconds: 0)
        XCTAssertThrowsError(try DrawingPathEncoder.encode(path))
    }

    func testVerifyReturnNilForCorruptData() {
        var data = Data(repeating: 0xFF, count: 20)
        // Wrong magic bytes
        XCTAssertNil(DrawingPathEncoder.verify(data))
        // Short data
        XCTAssertNil(DrawingPathEncoder.verify(Data([0xEB, 0x01])))
    }

    func testEncoderCRCDetectsCorruption() throws {
        let moves = [MoveCommand(direction: .east, runLength: 10)]
        let path = DrawingPath(moves: moves, widthInSteps: 100, heightInSteps: 100, estimatedDrawTimeSeconds: 1)
        let encoded = try DrawingPathEncoder.encode(path)
        var data = encoded.encodedData!
        // Corrupt a payload byte
        data[13] ^= 0xFF
        XCTAssertNil(DrawingPathEncoder.verify(data), "Corrupted data should fail CRC check")
    }

    // MARK: — DrawingPath estimated time string

    func testEstimatedTimeStringFormat() {
        let path60 = DrawingPath(moves: [], widthInSteps: 0, heightInSteps: 0, estimatedDrawTimeSeconds: 60)
        XCTAssertEqual(path60.estimatedDrawTimeString, "~1 min")

        let path90 = DrawingPath(moves: [], widthInSteps: 0, heightInSteps: 0, estimatedDrawTimeSeconds: 90)
        XCTAssertEqual(path90.estimatedDrawTimeString, "~1 min 30s")

        let path30 = DrawingPath(moves: [], widthInSteps: 0, heightInSteps: 0, estimatedDrawTimeSeconds: 30)
        XCTAssertEqual(path30.estimatedDrawTimeString, "~30s")
    }
}
