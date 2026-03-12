// TSPSolverTests.swift — EtchBot
// Tests for TSPSolver and PathOptimizer.

import XCTest
@testable import EtchBotCore

final class TSPSolverTests: XCTestCase {

    // MARK: — TSPSolver tests

    func testSolverProducesFullTour() async {
        let points: [StipplePoint] = (0..<20).map { i in
            .init(x: Float(i * 5), y: Float((i % 4) * 10))
        }
        var settings = DrawingSettings.defaults
        settings.tspStartingPositions = 2

        let tour = await TSPSolver.solve(points: points, settings: settings)
        XCTAssertEqual(tour.count, 20)
        // Each index appears exactly once
        let sorted = Set(tour)
        XCTAssertEqual(sorted.count, 20)
    }

    func testSolverSinglePoint() async {
        let points = [StipplePoint(x: 5, y: 5)]
        let tour = await TSPSolver.solve(points: points, settings: .defaults)
        XCTAssertEqual(tour, [0])
    }

    func testSolverTwoPoints() async {
        let points = [StipplePoint(x: 0, y: 0), StipplePoint(x: 1, y: 1)]
        let tour = await TSPSolver.solve(points: points, settings: .defaults)
        XCTAssertEqual(tour.count, 2)
    }

    func testBreakTourNearHome() {
        let points: [StipplePoint] = [
            .init(x: 100, y: 100),  // 0 — far from home
            .init(x: 200, y: 200),  // 1
            .init(x: 1, y: 1),      // 2 — nearest to home
            .init(x: 50, y: 50),    // 3
        ]
        let tour = [0, 1, 2, 3]
        let broken = TSPSolver.breakTourNearHome(tour: tour, points: points)
        XCTAssertEqual(broken.first, 2, "Tour should start at point nearest to home (index 2)")
    }

    func testTourLengthCalculation() {
        let points: [StipplePoint] = [
            .init(x: 0, y: 0),
            .init(x: 3, y: 0),
            .init(x: 3, y: 4),
        ]
        // Expected: 3 + 4 + 5 (3-4-5 right triangle) = 12
        let tour = [0, 1, 2]
        let length = TSPSolver.tourLength(points: points, tour: tour)
        XCTAssertEqual(length, 12.0, accuracy: 0.01)
    }

    // MARK: — PathOptimizer tests

    func testPathOptimizerProducesMovesForSimplePath() {
        let points: [StipplePoint] = [
            .init(x: 0, y: 0),
            .init(x: 10, y: 0),  // move right 10 units
            .init(x: 10, y: 5),  // move up 5 units
        ]
        let tour = [0, 1, 2]
        let calibration = CalibrationData(
            stepsPerMmHorizontal: 1.0,  // 1 step per density-unit for easy math
            stepsPerMmVertical: 1.0,
            backlashHorizontalSteps: 0,
            backlashVerticalSteps: 0
        )
        let path = PathOptimizer.optimize(
            tour: tour,
            points: points,
            densityMapWidth: 500,
            densityMapHeight: 320,
            calibration: calibration
        )
        XCTAssertFalse(path.moves.isEmpty)
    }

    func testPathOptimizerAllMovesInValidDirections() {
        let points: [StipplePoint] = (0..<10).map { i in
            .init(x: Float(i * 10), y: Float(i * 5))
        }
        let calibration = CalibrationData.defaults
        let path = PathOptimizer.optimize(
            tour: Array(0..<10),
            points: points,
            densityMapWidth: 500,
            densityMapHeight: 320,
            calibration: calibration
        )
        for move in path.moves {
            XCTAssertGreaterThan(move.runLength, 0)
            XCTAssertLessThanOrEqual(move.runLength, 8191)
        }
    }
}
