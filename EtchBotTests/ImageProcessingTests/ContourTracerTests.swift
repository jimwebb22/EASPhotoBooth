// ContourTracerTests.swift — EtchBotTests
// Tests for edge-map chain tracing, junction splitting, and simplification.

import XCTest
@testable import EtchBotCore

final class ContourTracerTests: XCTestCase {

    /// Build an edge map from ASCII art: '#' = edge pixel.
    private func edgeMap(_ rows: [String]) -> (map: [Float], width: Int, height: Int) {
        let height = rows.count
        let width = rows[0].count
        var map = [Float](repeating: 0, count: width * height)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                map[y * width + x] = 1
            }
        }
        return (map, width, height)
    }

    func testStraightLineTracesToSingleChain() {
        var rows = [String](repeating: String(repeating: ".", count: 30), count: 10)
        rows[5] = String(repeating: "#", count: 30)
        let (map, w, h) = edgeMap(rows)

        let chains = ContourTracer.trace(edgeMap: map, width: w, height: h,
                                         minChainPoints: 5, simplifyEpsilon: 0.75)
        XCTAssertEqual(chains.count, 1)
        // A perfectly straight line simplifies to its two endpoints.
        XCTAssertEqual(chains[0].count, 2)
        let xs = chains[0].map(\.x)
        XCTAssertEqual(xs.min()!, 0, accuracy: 0.01)
        XCTAssertEqual(xs.max()!, 29, accuracy: 0.01)
    }

    func testRectangleOutlineTracesAsLoop() {
        // 12×10 canvas with a rectangle border from (2,2) to (9,7).
        var rows = [String](repeating: String(repeating: ".", count: 12), count: 10)
        for y in 2...7 {
            var row = Array(String(repeating: ".", count: 12))
            if y == 2 || y == 7 {
                for x in 2...9 { row[x] = "#" }
            } else {
                row[2] = "#"; row[9] = "#"
            }
            rows[y] = String(row)
        }
        let (map, w, h) = edgeMap(rows)

        let chains = ContourTracer.trace(edgeMap: map, width: w, height: h,
                                         minChainPoints: 5, simplifyEpsilon: 0.75)
        XCTAssertEqual(chains.count, 1, "A closed rectangle outline should trace as one chain")
        let chain = chains[0]
        // Closed: first and last points coincide (ring closure).
        XCTAssertEqual(chain.first, chain.last,
            "Loop chain should be explicitly closed")
        // All corners must survive simplification.
        XCTAssertGreaterThanOrEqual(chain.count, 5)
    }

    func testShortChainsAreDiscarded() {
        var rows = [String](repeating: String(repeating: ".", count: 30), count: 10)
        rows[2] = "###" + String(repeating: ".", count: 27)          // 3 px — too short
        rows[6] = String(repeating: "#", count: 20) + String(repeating: ".", count: 10)
        let (map, w, h) = edgeMap(rows)

        let chains = ContourTracer.trace(edgeMap: map, width: w, height: h,
                                         minChainPoints: 10, simplifyEpsilon: 0.75)
        XCTAssertEqual(chains.count, 1, "Only the 20px chain should survive the length filter")
    }

    func testJunctionSplitsBranches() {
        // A "T": horizontal bar with a vertical stem meeting it in the middle.
        var rows = [String](repeating: String(repeating: ".", count: 21), count: 15)
        rows[3] = String(repeating: "#", count: 21)
        for y in 4..<14 {
            var row = Array(String(repeating: ".", count: 21))
            row[10] = "#"
            rows[y] = String(row)
        }
        let (map, w, h) = edgeMap(rows)

        let chains = ContourTracer.trace(edgeMap: map, width: w, height: h,
                                         minChainPoints: 4, simplifyEpsilon: 0.75)
        // The junction pixel region breaks the T into (at least) 3 chains:
        // left bar, right bar, stem.
        XCTAssertGreaterThanOrEqual(chains.count, 3)
    }

    func testEmptyMapProducesNoChains() {
        let map = [Float](repeating: 0, count: 100)
        let chains = ContourTracer.trace(edgeMap: map, width: 10, height: 10)
        XCTAssertTrue(chains.isEmpty)
    }

    // MARK: — Douglas–Peucker

    func testSimplifyPreservesCorner() {
        // An L-shape: right 10, then up 10.
        var pts = [StipplePoint]()
        for i in 0...10 { pts.append(.init(x: Float(i), y: 0)) }
        for i in 1...10 { pts.append(.init(x: 10, y: Float(i))) }

        let simplified = ContourTracer.simplify(pts, epsilon: 0.75)
        XCTAssertEqual(simplified.count, 3, "L-shape should simplify to start, corner, end")
        XCTAssertTrue(simplified.contains(StipplePoint(x: 10, y: 0)), "Corner must survive")
    }

    func testSimplifyKeepsEndpoints() {
        let pts: [StipplePoint] = (0...20).map { .init(x: Float($0), y: Float($0 % 2)) }
        let simplified = ContourTracer.simplify(pts, epsilon: 5.0)
        XCTAssertEqual(simplified.first, pts.first)
        XCTAssertEqual(simplified.last, pts.last)
    }

    // MARK: — Density subtraction

    func testSubtractChainsClearsCoverage() {
        let w = 20, h = 20
        let map = DensityMap(width: w, height: h, pixels: [Float](repeating: 1, count: w * h))
        let chain: [StipplePoint] = [.init(x: 2, y: 10), .init(x: 17, y: 10)]

        let reduced = ContourTracer.subtractChains(from: map, chains: [chain], radius: 1.5)

        // On the chain: cleared.
        XCTAssertEqual(reduced.value(x: 10, y: 10), 0)
        XCTAssertEqual(reduced.value(x: 2, y: 10), 0)
        // Far from the chain: untouched.
        XCTAssertEqual(reduced.value(x: 10, y: 2), 1)
        XCTAssertEqual(reduced.value(x: 10, y: 17), 1)
    }
}
