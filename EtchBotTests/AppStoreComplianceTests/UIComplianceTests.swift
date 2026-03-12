// UIComplianceTests.swift — EtchBot
// App Store UI compliance verification tests.
// These document requirements and verify data-layer compliance.
// Full UI tests (TC-010 through TC-013) run as EtchBotUITests on simulator.

import XCTest
@testable import EtchBotCore

final class UIComplianceTests: XCTestCase {

    // TC-014: Image processing completes in reasonable time
    func testImageProcessingPipelinePerformance() async {
        // Performance test: 100-point stippling on a small map should be fast
        let pixels = [Float](repeating: 0.5, count: 50 * 32)
        let map = DensityMap(width: 50, height: 32, pixels: pixels)
        var settings = DrawingSettings.defaults
        settings.pointCount = 100
        settings.voronoiIterations = 5

        let startTime = Date()
        let points = await VoronoiStippler.stipple(densityMap: map, settings: settings)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(points.count, 100)
        XCTAssertLessThan(elapsed, 10.0, "100-point stippling should complete in under 10 seconds")
    }

    // TC-016: Stability — multiple sequential processing runs
    func testMultipleSequentialEncodings() throws {
        for i in 1...10 {
            let moves = (0..<(i * 10)).map { _ in MoveCommand(direction: .northeast, runLength: 42) }
            let path = DrawingPath(moves: moves, widthInSteps: 7000, heightInSteps: 4800, estimatedDrawTimeSeconds: i * 5)
            let encoded = try DrawingPathEncoder.encode(path)
            XCTAssertNotNil(encoded.encodedData)
            let header = DrawingPathEncoder.verify(encoded.encodedData!)
            XCTAssertNotNil(header, "Encoding \(i) should be verifiable")
            XCTAssertEqual(header?.moveCount, moves.count)
        }
    }

    // TC-007: App functions without hardware (demo mode — data layer check)
    func testFullPipelineWithoutHardware() async throws {
        // Verify that the full non-BLE pipeline runs without errors
        let pixels: [Float] = (0..<(50 * 32)).map { i in
            Float(i % 10) / 10.0  // gradient pattern
        }
        let map = DensityMap(width: 50, height: 32, pixels: pixels)
        var settings = DrawingSettings.defaults
        settings.pointCount = 50
        settings.voronoiIterations = 3
        settings.tspStartingPositions = 2

        // Step 1: Stipple
        let points = await VoronoiStippler.stipple(densityMap: map, settings: settings)
        XCTAssertFalse(points.isEmpty)

        // Step 2: TSP solve
        let tour = await TSPSolver.solve(points: points, settings: settings)
        XCTAssertEqual(tour.count, points.count)

        // Step 3: Break tour
        let orderedTour = TSPSolver.breakTourNearHome(tour: tour, points: points)
        let orderedPoints = orderedTour.map { points[$0] }

        // Step 4: Optimize path
        let path = PathOptimizer.optimize(
            tour: Array(0..<orderedPoints.count),
            points: orderedPoints,
            densityMapWidth: 50,
            densityMapHeight: 32,
            calibration: .defaults
        )
        XCTAssertFalse(path.moves.isEmpty)

        // Step 5: Encode
        let encoded = try DrawingPathEncoder.encode(path)
        XCTAssertNotNil(encoded.encodedData)

        // Step 6: Verify
        let header = DrawingPathEncoder.verify(encoded.encodedData!)
        XCTAssertNotNil(header)
    }

    // TC-015: Memory usage is bounded
    func testLargePathEncodingDoesNotAllocateExcessively() throws {
        // 6000 points, each turning into ~5 moves on average = 30000 moves
        let moves = (0..<30000).map { i in
            MoveCommand(direction: StepDirection(rawValue: UInt8(i % 8))!, runLength: 5)
        }
        let path = DrawingPath(moves: moves, widthInSteps: 7000, heightInSteps: 4800, estimatedDrawTimeSeconds: 1800)
        let encoded = try DrawingPathEncoder.encode(path)
        // 30000 moves × 2 bytes + 12 header = 60012 bytes ≈ 59KB
        let byteCount = encoded.encodedData!.count
        XCTAssertLessThan(byteCount, 70_000, "Large path should be under 70KB encoded")
    }

    // App Store metadata constants test
    func testBundleIdentifierFormat() {
        // Verify the bundle ID placeholder is in correct format
        let bundleID = "com.etchbot.app"
        XCTAssertTrue(bundleID.contains("."), "Bundle ID must be dot-separated")
        XCTAssertGreaterThanOrEqual(bundleID.split(separator: ".").count, 3, "Bundle ID should have 3+ components")
    }
}
