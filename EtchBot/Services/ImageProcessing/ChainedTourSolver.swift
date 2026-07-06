// ChainedTourSolver.swift — EtchBot
// Orders a mixed set of tour elements — single stipple points and traced
// contour polyline chains — into one continuous polyline.
//
// Chains are mandatory path segments: they are always drawn along their own
// points (forward or reversed); the solver only optimizes the CONNECTORS
// between element endpoints. This is what makes the hybrid render style
// follow image contours instead of hopping between dots.
//
// Algorithm:
//   1. Greedy construction: starting from the home corner (0,0), repeatedly
//      jump to the nearest unvisited element endpoint (KD-tree) and traverse
//      that element, entering at that endpoint.
//   2. Orientation-aware 2-opt: reversing a subsequence of elements (and
//      flipping each one's traversal direction) preserves all internal
//      connector lengths, so the cost delta involves only the two boundary
//      connectors — an O(1) evaluation, exactly like point 2-opt.

import Foundation

/// One element of the drawing: a lone stipple point or a contour chain.
public enum TourElement: Sendable {
    case point(StipplePoint)
    case chain([StipplePoint])  // at least 2 points

    var pointList: [StipplePoint] {
        switch self {
        case .point(let p): return [p]
        case .chain(let pts): return pts
        }
    }
}

public final class ChainedTourSolver: Sendable {

    /// Candidates considered per element in the 2-opt phase.
    private static let candidateCount = 8
    private static let maxPasses = 15

    // MARK: — Public entry point

    /// Order the elements into a single drawable polyline.
    /// The result starts near the home corner (0, 0).
    public static func solve(elements: [TourElement], seed: UInt64? = nil) -> [StipplePoint] {
        let elems = elements.map { $0.pointList }.filter { !$0.isEmpty }
        guard !elems.isEmpty else { return [] }
        guard elems.count > 1 else { return elems[0] }

        let m = elems.count

        // Endpoint table: endpoint 2e = first point of element e, 2e+1 = last.
        var endpoints = [StipplePoint]()
        endpoints.reserveCapacity(2 * m)
        for pts in elems {
            endpoints.append(pts.first!)
            endpoints.append(pts.last!)
        }
        let kdTree = KDTree(points: endpoints)

        // ── Phase 1: greedy nearest-endpoint construction from home ─────────
        // order[pos] = element index; orient[pos] = true when traversed reversed
        // (entered at its last point).
        var order = [Int]()
        var orient = [Bool]()
        order.reserveCapacity(m)
        orient.reserveCapacity(m)

        var excluded = Set<Int>()
        excluded.reserveCapacity(2 * m)
        var current = StipplePoint(x: 0, y: 0)  // home corner

        while order.count < m {
            guard let nearest = kdTree.nearestIndex(to: current, excluding: excluded) else { break }
            let e = nearest / 2
            let enterAtLast = (nearest % 2 == 1)
            order.append(e)
            orient.append(enterAtLast)
            excluded.insert(2 * e)
            excluded.insert(2 * e + 1)
            current = enterAtLast ? endpoints[2 * e] : endpoints[2 * e + 1]  // exit point
        }

        // ── Phase 2: orientation-aware 2-opt over connectors ────────────────
        var elemPosition = [Int](repeating: 0, count: m)
        for (pos, e) in order.enumerated() { elemPosition[e] = pos }

        func entryPoint(_ pos: Int) -> StipplePoint {
            let e = order[pos]
            return orient[pos] ? endpoints[2 * e + 1] : endpoints[2 * e]
        }
        func exitPoint(_ pos: Int) -> StipplePoint {
            let e = order[pos]
            return orient[pos] ? endpoints[2 * e] : endpoints[2 * e + 1]
        }

        var pass = 0
        var improved = true
        while improved && pass < maxPasses {
            improved = false
            pass += 1

            for i in 0..<(m - 1) {
                let exitI = exitPoint(i)
                let connectorI = exitI.distance(to: entryPoint(i + 1))

                var bestDelta: Float = -1e-3
                var bestJ = -1

                // Candidate elements whose endpoints are near exit(i): after
                // reversing i+1...j, the new connector is exit(i) → exit(j).
                for candidateEndpoint in kdTree.kNearest(to: exitI, k: candidateCount) {
                    let j = elemPosition[candidateEndpoint / 2]
                    guard j >= i + 1 else { continue }

                    let newFirst = exitI.distance(to: exitPoint(j))
                    let delta: Float
                    if j < m - 1 {
                        let oldSecond = exitPoint(j).distance(to: entryPoint(j + 1))
                        let newSecond = entryPoint(i + 1).distance(to: entryPoint(j + 1))
                        delta = newFirst + newSecond - connectorI - oldSecond
                    } else {
                        // Tail reversal: only the first boundary connector changes.
                        delta = newFirst - connectorI
                    }
                    if delta < bestDelta {
                        bestDelta = delta
                        bestJ = j
                    }
                }

                if bestJ >= 0 {
                    // Reverse order[i+1...bestJ] and flip orientations.
                    var l = i + 1
                    var h = bestJ
                    while l < h {
                        order.swapAt(l, h)
                        orient.swapAt(l, h)
                        l += 1
                        h -= 1
                    }
                    for pos in (i + 1)...bestJ {
                        orient[pos].toggle()
                        elemPosition[order[pos]] = pos
                    }
                    improved = true
                }
            }
        }

        // ── Emit the polyline ────────────────────────────────────────────────
        var polyline = [StipplePoint]()
        polyline.reserveCapacity(elems.reduce(0) { $0 + $1.count })
        for pos in 0..<m {
            let pts = orient[pos] ? Array(elems[order[pos]].reversed()) : elems[order[pos]]
            for p in pts where p != polyline.last {
                polyline.append(p)
            }
        }
        return polyline
    }
}
