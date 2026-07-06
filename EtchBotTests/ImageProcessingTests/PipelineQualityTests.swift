// PipelineQualityTests.swift — EtchBotTests
// Quality-regression harness (WS0 of the line-quality improvement plan).
//
// Guards the geometry invariants fixed in WS1:
//   - encoded paths are purely geometric (no backlash excursions)  [WS1.1/1.2]
//   - X and Y map pixels to steps with a uniform scale             [WS1.3]
// and reports (without yet asserting) the stippling-quality metrics that
// WS2/WS3/WS4 will improve, so each workstream has a recorded baseline.

import XCTest
@testable import EtchBotCore

final class PipelineQualityTests: XCTestCase {

    // MARK: — WS1.1/1.2: encoded path is purely geometric

    /// Converts working-space waypoints to step space exactly the way
    /// PathOptimizer does, so tests can compute expected geometry.
    private func stepCoords(
        _ points: [StipplePoint],
        calibration: CalibrationData
    ) -> [(x: Int, y: Int)] {
        let scaleX = Double(calibration.drawingAreaWidthSteps) / Double(WorkingCanvas.width)
        let scaleY = Double(calibration.drawingAreaHeightSteps) / Double(WorkingCanvas.height)
        return points.map {
            (x: Int((Double($0.x) * scaleX).rounded()),
             y: Int((Double($0.y) * scaleY).rounded()))
        }
    }

    /// Ideal 8-direction path length between waypoints (Bresenham traverses
    /// each segment in max(|dx|, |dy|) steps).
    private func chebyshevPathLength(_ coords: [(x: Int, y: Int)]) -> Int {
        guard coords.count > 1 else { return 0 }
        var total = 0
        for i in 1..<coords.count {
            total += max(abs(coords[i].x - coords[i - 1].x), abs(coords[i].y - coords[i - 1].y))
        }
        return total
    }

    /// A short out-and-back reversal must produce exactly one pen reversal
    /// and exactly the geometric number of motor steps. The pre-WS1 encoder
    /// injected backlash steps AND shifted its logical cursor, which produced
    /// an overshoot-and-return (two extra reversals) plus surplus motor steps
    /// at every direction change — this test fails against that code.
    func testReversalPathIsPurelyGeometric() {
        // Horizontal out-and-back with a reversal segment (2 px ≈ 28 steps)
        // shorter than the default 60-step backlash placeholder.
        let points: [StipplePoint] = [
            .init(x: 100, y: 50),
            .init(x: 50, y: 50),
            .init(x: 52, y: 50),
        ]
        let calibration = CalibrationData.defaults  // non-zero backlash values
        let path = PathOptimizer.optimize(
            tour: [0, 1, 2],
            points: points,
            densityMapWidth: WorkingCanvas.width,
            densityMapHeight: WorkingCanvas.height,
            calibration: calibration
        )

        let coords = stepCoords(points, calibration: calibration)
        let traj = PlotSimulator.run(moves: path.moves)

        // Exactly the geometric step count — no compensation surplus.
        XCTAssertEqual(traj.motorSteps, chebyshevPathLength(coords),
            "Encoded path contains non-geometric moves (backlash leakage?)")

        // Exactly one X reversal (west then east), no Y motion.
        let reversals = traj.axisReversalCounts
        XCTAssertEqual(reversals.x, 1,
            "Out-and-back tour must reverse X exactly once; extra reversals are excursion artifacts")
        XCTAssertEqual(reversals.y, 0)

        // Final pen position lands exactly on the last waypoint (relative to start).
        XCTAssertEqual(traj.finalPen.x, coords[2].x - coords[0].x)
        XCTAssertEqual(traj.finalPen.y, 0)
    }

    /// Same invariant on a 2D zigzag tour with reversals on both axes.
    func testZigzagTourMotorTravelEqualsGeometricTravel() {
        let points: [StipplePoint] = [
            .init(x: 10, y: 10),
            .init(x: 60, y: 40),
            .init(x: 20, y: 25),
            .init(x: 70, y: 5),
            .init(x: 15, y: 60),
        ]
        let calibration = CalibrationData.defaults
        let path = PathOptimizer.optimize(
            tour: Array(0..<points.count),
            points: points,
            densityMapWidth: WorkingCanvas.width,
            densityMapHeight: WorkingCanvas.height,
            calibration: calibration
        )
        let coords = stepCoords(points, calibration: calibration)
        let traj = PlotSimulator.run(moves: path.moves)
        XCTAssertEqual(traj.motorSteps, chebyshevPathLength(coords))
        XCTAssertEqual(traj.finalPen.x, coords.last!.x - coords[0].x)
        XCTAssertEqual(traj.finalPen.y, coords.last!.y - coords[0].y)
    }

    // MARK: — WS1.3: uniform pixel→step scale (no aspect distortion)

    func testCanvasToStepScaleIsUniform() {
        let calibration = CalibrationData.defaults
        let scaleX = Double(calibration.drawingAreaWidthSteps) / Double(WorkingCanvas.width)
        let scaleY = Double(calibration.drawingAreaHeightSteps) / Double(WorkingCanvas.height)
        // Pre-WS1.3 this was 14 vs 15 (a 7% vertical stretch).
        XCTAssertEqual(scaleX / scaleY, 1.0, accuracy: 0.005,
            "Working canvas aspect no longer matches the physical drawing area — images will be stretched")
    }

    func testWorkingCanvasMatchesPhysicalAspect() {
        let canvasAspect = Double(WorkingCanvas.width) / Double(WorkingCanvas.height)
        let physicalAspect = 175.0 / 120.0
        XCTAssertEqual(canvasAspect, physicalAspect, accuracy: 0.01)
    }

    // MARK: — PlotSimulator self-tests (the harness must model lash correctly)

    func testSimulatorLashModelAbsorbsReversalSlack() {
        // East 100, then west 100, with 20 steps of lash.
        let moves = [
            MoveCommand(direction: .east, runLength: 100),
            MoveCommand(direction: .west, runLength: 100),
        ]
        let traj = PlotSimulator.run(moves: moves, lashX: 20)
        // Starts engaged forward: east moves pen fully (+100). Reversing, the
        // first 20 west steps cross the gap, so the pen only returns 80.
        XCTAssertEqual(traj.finalPen.x, 20)
        XCTAssertEqual(traj.motorSteps, 200)
    }

    func testSimulatorIdealMechanismTracksExactly() {
        let moves = [
            MoveCommand(direction: .east, runLength: 10),
            MoveCommand(direction: .northeast, runLength: 5),
            MoveCommand(direction: .south, runLength: 3),
        ]
        let traj = PlotSimulator.run(moves: moves)
        XCTAssertEqual(traj.finalPen.x, 15)
        XCTAssertEqual(traj.finalPen.y, 2)
    }

    // MARK: — Baseline quality metrics (reported, not yet asserted)

    /// Records the stippling-quality baseline for the WS2 workstream.
    /// Once WS2 lands (white cutoff, no uniform fill), the blank-fixture
    /// metric below should be asserted to be zero.
    func testStipplingQualityBaselineMetrics() async {
        var settings = DrawingSettings.defaults
        settings.pointCount = 200
        settings.voronoiIterations = 8

        let fixtures: [(name: String, map: DensityMap)] = [
            ("blankWithDisc", DensityFixtures.blankWithDisc()),
            ("gradientRamp", DensityFixtures.gradientRamp()),
            ("silhouette", DensityFixtures.silhouette()),
        ]

        print("─── Stippling quality baseline ───────────────────────────")
        print("fixture          points   inWhiteRegion   inWhitePercent")
        for fixture in fixtures {
            let points = await VoronoiStippler.stipple(densityMap: fixture.map, settings: settings)
            let inWhite = points.filter { fixture.map.interpolate(fx: $0.x, fy: $0.y) < 0.01 }.count
            let pct = points.isEmpty ? 0 : Double(inWhite) / Double(points.count) * 100
            let name = fixture.name.padding(toLength: 16, withPad: " ", startingAt: 0)
            print("\(name) \(points.count)      \(inWhite)              \(String(format: "%.1f", pct))%")

            // Weak invariants that must always hold.
            XCTAssertFalse(points.isEmpty)
            for p in points {
                XCTAssertTrue(p.x >= 0 && p.x < Float(fixture.map.width))
                XCTAssertTrue(p.y >= 0 && p.y < Float(fixture.map.height))
            }
        }
        print("──────────────────────────────────────────────────────────")
    }

    /// Records the tour-quality baseline for the WS3 workstream:
    /// open-path length and the length of the longest drawn edge.
    func testTourQualityBaselineMetrics() async {
        var settings = DrawingSettings.defaults
        settings.pointCount = 150
        settings.voronoiIterations = 5

        let map = DensityFixtures.silhouette()
        let points = await VoronoiStippler.stipple(densityMap: map, settings: settings)
        let tour = await TSPSolver.solve(points: points, settings: settings)
        let ordered = TSPSolver.breakTourNearHome(tour: tour, points: points)

        var openLength = 0.0
        var longestEdge = 0.0
        for i in 1..<ordered.count {
            let d = Double(points[ordered[i - 1]].distance(to: points[ordered[i]]))
            openLength += d
            longestEdge = max(longestEdge, d)
        }

        print("─── Tour quality baseline ────────────────────────────────")
        print(String(format: "openPathLength: %.1f   longestDrawnEdge: %.1f   points: %d",
                     openLength, longestEdge, points.count))
        print("──────────────────────────────────────────────────────────")

        XCTAssertEqual(Set(ordered).count, points.count, "Tour must visit every point exactly once")
        XCTAssertGreaterThan(openLength, 0)
    }
}
