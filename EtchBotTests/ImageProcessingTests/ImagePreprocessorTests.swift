// ImagePreprocessorTests.swift — EtchBot
// Tests for DensityMap and edge detector (platform-independent portions).

import XCTest
@testable import EtchBotCore

final class ImagePreprocessorTests: XCTestCase {

    // MARK: — DensityMap tests

    func testDensityMapValueAtBounds() {
        let pixels: [Float] = [0, 0.5, 1.0, 0.25]
        let map = DensityMap(width: 2, height: 2, pixels: pixels)
        XCTAssertEqual(map.value(x: 0, y: 0), 0.0)
        XCTAssertEqual(map.value(x: 1, y: 0), 0.5)
        XCTAssertEqual(map.value(x: 0, y: 1), 1.0)
        XCTAssertEqual(map.value(x: 1, y: 1), 0.25)
    }

    func testDensityMapOutOfBoundsReturnsZero() {
        let map = DensityMap(width: 2, height: 2, pixels: [0.5, 0.5, 0.5, 0.5])
        XCTAssertEqual(map.value(x: -1, y: 0), 0)
        XCTAssertEqual(map.value(x: 2, y: 0), 0)
        XCTAssertEqual(map.value(x: 0, y: -1), 0)
        XCTAssertEqual(map.value(x: 0, y: 2), 0)
    }

    func testDensityMapBilinearInterpolation() {
        let pixels: [Float] = [0, 1, 0, 1]  // alternating 0 and 1
        let map = DensityMap(width: 2, height: 2, pixels: pixels)
        // At the centre (0.5, 0.5) should be average ≈ 0.5
        let v = map.interpolate(fx: 0.5, fy: 0.5)
        XCTAssertEqual(v, 0.5, accuracy: 0.01)
    }

    // MARK: — CRC-16 tests

    func testCRC16KnownValue() {
        // CRC-16/IBM of "123456789" = 0xBB3D (standard test vector)
        let data = "123456789".data(using: .ascii)!
        XCTAssertEqual(data.crc16, 0xBB3D)
    }

    func testCRC16EmptyData() {
        let data = Data()
        XCTAssertEqual(data.crc16, 0x0000)
    }

    func testCRC16ChangeDetection() {
        let data1 = Data([0x01, 0x02, 0x03])
        let data2 = Data([0x01, 0x02, 0x04])  // one byte changed
        XCTAssertNotEqual(data1.crc16, data2.crc16)
    }

    // MARK: — Edge detector (pure Swift, no UIKit)

    func testEdgeDetectorProducesEdgesOnHighContrast() throws {
        // Create a 20x20 image: left half black (0), right half white (1)
        var pixels = [Float](repeating: 0, count: 20 * 20)
        for y in 0..<20 {
            for x in 10..<20 { pixels[y * 20 + x] = 1.0 }
        }
        let edges = try EdgeDetector.canny(pixels: pixels, width: 20, height: 20)
        XCTAssertEqual(edges.count, 400)
        // The edge column (x≈10) should have nonzero edge values
        let edgeColumn = (1..<19).map { y in edges[y * 20 + 10] }
        let hasEdge = edgeColumn.contains { $0 > 0 }
        XCTAssertTrue(hasEdge, "Should detect edge at boundary")
    }

    func testEdgeDetectorFlatImageProducesNoEdges() throws {
        let pixels = [Float](repeating: 0.5, count: 20 * 20)
        let edges = try EdgeDetector.canny(pixels: pixels, width: 20, height: 20)
        let maxEdge = edges.max() ?? 0
        XCTAssertEqual(maxEdge, 0, "Flat image should have no edges")
    }
}
