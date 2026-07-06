// ChainedTourSolverTests.swift — EtchBotTests
// Tests for the mixed chain+point ordering solver used by the hybrid style.

import XCTest
@testable import EtchBotCore

final class ChainedTourSolverTests: XCTestCase {

    func testEmptyInput() {
        XCTAssertTrue(ChainedTourSolver.solve(elements: []).isEmpty)
    }

    func testSinglePointElement() {
        let p = StipplePoint(x: 5, y: 7)
        let result = ChainedTourSolver.solve(elements: [.point(p)])
        XCTAssertEqual(result, [p])
    }

    func testSingleChainPassthrough() {
        let chain: [StipplePoint] = [.init(x: 0, y: 0), .init(x: 5, y: 0), .init(x: 5, y: 5)]
        let result = ChainedTourSolver.solve(elements: [.chain(chain)])
        XCTAssertEqual(result, chain)
    }

    /// Every chain must appear in the output as a contiguous run of its own
    /// points, forward or reversed — chains are mandatory path segments.
    func testChainsAreTraversedContiguously() {
        let chainA: [StipplePoint] = [.init(x: 10, y: 10), .init(x: 20, y: 10), .init(x: 30, y: 15)]
        let chainB: [StipplePoint] = [.init(x: 100, y: 100), .init(x: 110, y: 105), .init(x: 120, y: 100)]
        let loosePoints: [StipplePoint] = [.init(x: 60, y: 50), .init(x: 5, y: 90)]

        let elements: [TourElement] = [.chain(chainA), .chain(chainB)]
                                    + loosePoints.map { TourElement.point($0) }
        let polyline = ChainedTourSolver.solve(elements: elements)

        XCTAssertTrue(containsContiguous(polyline, chainA), "Chain A must be drawn contiguously")
        XCTAssertTrue(containsContiguous(polyline, chainB), "Chain B must be drawn contiguously")
        for p in loosePoints {
            XCTAssertTrue(polyline.contains(p), "Loose point \(p) missing from polyline")
        }
    }

    func testStartsNearHome() {
        // One element sits at the home corner; it must be drawn first.
        let nearHome = StipplePoint(x: 1, y: 1)
        let elements: [TourElement] = [
            .point(StipplePoint(x: 400, y: 300)),
            .point(nearHome),
            .chain([.init(x: 200, y: 200), .init(x: 250, y: 220)]),
        ]
        let polyline = ChainedTourSolver.solve(elements: elements)
        XCTAssertEqual(polyline.first, nearHome)
    }

    func testTwoOptImprovesOrDoesNotWorsenGreedyOrder() {
        // A grid of points — the solver must produce a polyline visiting all
        // of them; sanity-check total length against a naive raster order.
        var elements = [TourElement]()
        var rasterOrder = [StipplePoint]()
        for y in 0..<8 {
            for x in 0..<8 {
                let p = StipplePoint(x: Float(x) * 10, y: Float(y) * 10)
                elements.append(.point(p))
                rasterOrder.append(p)
            }
        }
        let polyline = ChainedTourSolver.solve(elements: elements)
        XCTAssertEqual(polyline.count, 64)

        func length(_ pts: [StipplePoint]) -> Float {
            guard pts.count > 1 else { return 0 }
            var total: Float = 0
            for i in 1..<pts.count { total += pts[i - 1].distance(to: pts[i]) }
            return total
        }
        // Raster order (with flyback jumps) is a weak upper bound the solver
        // should comfortably beat on a grid.
        XCTAssertLessThan(length(polyline), length(rasterOrder))
    }

    // MARK: — Helpers

    /// True if `needle` (or its reverse) appears as a consecutive subsequence.
    private func containsContiguous(_ haystack: [StipplePoint], _ needle: [StipplePoint]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        let reversed = Array(needle.reversed())
        for start in 0...(haystack.count - needle.count) {
            let window = Array(haystack[start..<(start + needle.count)])
            if window == needle || window == reversed { return true }
        }
        return false
    }
}
