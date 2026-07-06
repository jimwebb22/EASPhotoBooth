// VoronoiStipplerTests.swift — EtchBot
// Tests for KDTree, VoronoiDiagram, and VoronoiStippler.

import XCTest
@testable import EtchBotCore

final class VoronoiStipplerTests: XCTestCase {

    // MARK: — KDTree tests

    func testKDTreeNearestNeighbour() {
        let points: [StipplePoint] = [
            .init(x: 0, y: 0),
            .init(x: 10, y: 0),
            .init(x: 0, y: 10),
            .init(x: 10, y: 10),
        ]
        let tree = KDTree(points: points)
        // Query near (9, 1) → nearest should be (10, 0) = index 1
        let idx = tree.nearestIndex(to: .init(x: 9, y: 1))
        XCTAssertEqual(idx, 1)
    }

    func testKDTreeExcludingVisited() {
        let points: [StipplePoint] = [
            .init(x: 0, y: 0),  // 0
            .init(x: 1, y: 0),  // 1 — nearest to (0.5, 0) but excluded
            .init(x: 5, y: 0),  // 2 — should be returned
        ]
        let tree = KDTree(points: points)
        let idx = tree.nearestIndex(to: .init(x: 0.5, y: 0), excluding: [1])
        XCTAssertTrue(idx == 0 || idx == 2, "Should skip index 1")
    }

    func testKDTreeKNearest() {
        let points: [StipplePoint] = (0..<10).map { .init(x: Float($0), y: 0) }
        let tree = KDTree(points: points)
        let k3 = tree.kNearest(to: .init(x: 5, y: 0), k: 3)
        XCTAssertEqual(k3.count, 3)
        // Index 5 (x=5) should be nearest
        XCTAssertTrue(k3.contains(5))
    }

    func testKDTreeSinglePoint() {
        let tree = KDTree(points: [.init(x: 1, y: 2)])
        let idx = tree.nearestIndex(to: .init(x: 100, y: 100))
        XCTAssertEqual(idx, 0)
    }

    func testKDTreeEmptyReturnsNil() {
        let tree = KDTree(points: [])
        let idx = tree.nearestIndex(to: .init(x: 0, y: 0))
        XCTAssertNil(idx)
    }

    // MARK: — Jump-flood assignment

    /// The JFA pixel assignment must agree with brute-force nearest-site
    /// search. JFA+1 is near-exact but not provably exact, so allow a tiny
    /// error budget: every pixel within 0.75px of optimal, ≥99% exact.
    func testJumpFloodMatchesBruteForceNearest() {
        var rng = SeededRandomNumberGenerator(seed: 5)
        let w = 40, h = 30
        let points: [StipplePoint] = (0..<25).map { _ in
            .init(x: Float.random(in: 0..<Float(w), using: &rng),
                  y: Float.random(in: 0..<Float(h), using: &rng))
        }
        let labels = VoronoiDiagram.assignPixels(points: points, width: w, height: h)

        var exactCount = 0
        for y in 0..<h {
            for x in 0..<w {
                let label = Int(labels[y * w + x])
                XCTAssertGreaterThanOrEqual(label, 0, "Every pixel must be assigned")
                let q = StipplePoint(x: Float(x), y: Float(y))
                let assigned = q.distance(to: points[label])
                let best = points.map { q.distance(to: $0) }.min()!
                XCTAssertLessThanOrEqual(assigned, best + 0.75,
                    "Pixel (\(x),\(y)) assigned to a site far from optimal")
                if assigned - best < 1e-4 { exactCount += 1 }
            }
        }
        XCTAssertGreaterThan(Double(exactCount) / Double(w * h), 0.99)
    }

    func testJumpFloodSeparatesTwoSites() {
        let points: [StipplePoint] = [.init(x: 5, y: 10), .init(x: 35, y: 10)]
        let labels = VoronoiDiagram.assignPixels(points: points, width: 40, height: 20)
        XCTAssertEqual(labels[10 * 40 + 2], 0)
        XCTAssertEqual(labels[10 * 40 + 38], 1)
    }

    // MARK: — VoronoiDiagram weighted centroid tests

    func testWeightedCentroidSinglePoint() {
        // One point at (0, 0), uniform density — centroid should be at image centre
        let pixels = [Float](repeating: 1.0, count: 10 * 10)
        let map = DensityMap(width: 10, height: 10, pixels: pixels)
        let points = [StipplePoint(x: 3, y: 3)]
        let result = VoronoiDiagram.computeWeightedCentroids(points: points, densityMap: map)
        XCTAssertNotNil(result.centroids[0])
        // With uniform density and one point, centroid ≈ image centre (4.5, 4.5)
        XCTAssertEqual(result.centroids[0]!.x, 4.5, accuracy: 1.0)
        XCTAssertEqual(result.centroids[0]!.y, 4.5, accuracy: 1.0)
    }

    func testConvergenceDetection() {
        let old: [StipplePoint] = [.init(x: 0, y: 0), .init(x: 10, y: 10)]
        let new = old  // No movement
        XCTAssertTrue(VoronoiDiagram.hasConverged(old: old, new: new, threshold: 0.5))
    }

    func testNoConvergenceDetection() {
        let old: [StipplePoint] = [.init(x: 0, y: 0), .init(x: 10, y: 10)]
        let new: [StipplePoint] = [.init(x: 5, y: 5), .init(x: 15, y: 15)]
        XCTAssertFalse(VoronoiDiagram.hasConverged(old: old, new: new, threshold: 0.5))
    }

    // MARK: — StipplePoint tests

    func testStipplePointDistance() {
        let a = StipplePoint(x: 0, y: 0)
        let b = StipplePoint(x: 3, y: 4)
        XCTAssertEqual(a.distance(to: b), 5.0, accuracy: 0.001)
    }

    func testStipplePointDistanceSquared() {
        let a = StipplePoint(x: 0, y: 0)
        let b = StipplePoint(x: 3, y: 4)
        XCTAssertEqual(a.distanceSquared(to: b), 25.0, accuracy: 0.001)
    }

    // MARK: — VoronoiStippler integration test

    func testStipplerProducesRequestedPointCount() async {
        let pixels = [Float](repeating: 0.5, count: 50 * 32)
        let map = DensityMap(width: 50, height: 32, pixels: pixels)
        var settings = DrawingSettings.defaults
        settings.pointCount = 100
        settings.voronoiIterations = 5  // Fast for testing

        let points = await VoronoiStippler.stipple(densityMap: map, settings: settings)
        // pointCount is an upper bound; on a uniform positive-density map the
        // count should be met, minus at most a couple of near-coincident
        // points that lose their Voronoi cell.
        XCTAssertLessThanOrEqual(points.count, 100)
        XCTAssertGreaterThanOrEqual(points.count, 97)
    }

    func testStipplerPointsWithinBounds() async {
        let pixels = [Float](repeating: 0.8, count: 50 * 32)
        let map = DensityMap(width: 50, height: 32, pixels: pixels)
        var settings = DrawingSettings.defaults
        settings.pointCount = 50
        settings.voronoiIterations = 3

        let points = await VoronoiStippler.stipple(densityMap: map, settings: settings)
        for p in points {
            XCTAssertGreaterThanOrEqual(p.x, 0)
            XCTAssertLessThan(p.x, 50)
            XCTAssertGreaterThanOrEqual(p.y, 0)
            XCTAssertLessThan(p.y, 32)
        }
    }
}
