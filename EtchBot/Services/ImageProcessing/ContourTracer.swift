// ContourTracer.swift — EtchBot
// Traces a binary edge map (Canny output) into polyline chains that the
// hybrid render style draws as mandatory contour segments.
//
// Pipeline:
//   1. Threshold the edge map to a binary grid.
//   2. Mark junction pixels (≥3 edge neighbors); chains never cross them,
//      so branching structures split into separate chains.
//   3. Walk open chains starting from endpoints, then closed loops from
//      whatever non-junction pixels remain.
//   4. Discard chains shorter than `minChainPoints`.
//   5. Simplify each chain with Douglas–Peucker (default ε = 0.75 px).

import Foundation

public final class ContourTracer: Sendable {

    // MARK: — Public entry points

    /// Trace an edge map into simplified polyline chains.
    ///
    /// - Parameters:
    ///   - edgeMap: Row-major Float array (0 = no edge, 1 = edge), width×height.
    ///   - width/height: Edge-map dimensions (working resolution).
    ///   - minChainPoints: Chains with fewer traced pixels are discarded.
    ///   - simplifyEpsilon: Douglas–Peucker tolerance in pixels.
    /// - Returns: Chains as StipplePoint polylines in working coordinates.
    public static func trace(
        edgeMap: [Float],
        width: Int,
        height: Int,
        minChainPoints: Int = 10,
        simplifyEpsilon: Float = 0.75
    ) -> [[StipplePoint]] {
        guard width > 0, height > 0, edgeMap.count == width * height else { return [] }
        let n = width * height

        var isEdge = [Bool](repeating: false, count: n)
        for i in 0..<n where edgeMap[i] > 0.5 { isEdge[i] = true }

        // 8-neighborhood offsets in CIRCULAR order (E, SE, S, SW, W, NW, N, NE)
        // — the crossing-number computation below depends on this ordering.
        let nbrDX = [1, 1, 0, -1, -1, -1, 0, 1]
        let nbrDY = [0, 1, 1, 1, 0, -1, -1, -1]

        func edgeAt(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < width, y >= 0, y < height else { return false }
            return isEdge[y * width + x]
        }

        // Junction pixels break chains so branches become separate chains.
        // A pixel is a junction when its crossing number — the count of 0→1
        // transitions walking the 8-neighborhood ring — is ≥ 3: a line
        // interior has 2, an endpoint 1. (A raw neighbor count misclassifies
        // pixels next to corners, fragmenting closed outlines.)
        var isJunction = [Bool](repeating: false, count: n)
        for y in 0..<height {
            for x in 0..<width where isEdge[y * width + x] {
                var transitions = 0
                for k in 0..<8 {
                    let a = edgeAt(x + nbrDX[k], y + nbrDY[k])
                    let b = edgeAt(x + nbrDX[(k + 1) % 8], y + nbrDY[(k + 1) % 8])
                    if !a && b { transitions += 1 }
                }
                if transitions >= 3 { isJunction[y * width + x] = true }
            }
        }

        var visited = [Bool](repeating: false, count: n)

        /// Unvisited, non-junction edge neighbors of (x, y).
        func walkableNeighbors(_ x: Int, _ y: Int) -> [(x: Int, y: Int)] {
            var result: [(x: Int, y: Int)] = []
            for k in 0..<8 {
                let nx = x + nbrDX[k]
                let ny = y + nbrDY[k]
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let idx = ny * width + nx
                if isEdge[idx] && !isJunction[idx] && !visited[idx] {
                    result.append((nx, ny))
                }
            }
            return result
        }

        /// Walk from (sx, sy) as far as the chain continues.
        func walkChain(fromX sx: Int, fromY sy: Int) -> [StipplePoint] {
            var chain: [StipplePoint] = []
            var cx = sx
            var cy = sy
            while true {
                visited[cy * width + cx] = true
                chain.append(StipplePoint(x: Float(cx), y: Float(cy)))
                let next = walkableNeighbors(cx, cy)
                guard let step = next.first else { break }
                cx = step.x
                cy = step.y
            }
            return chain
        }

        var chains: [[StipplePoint]] = []

        // Pass 1: open chains — start from endpoints of the non-junction subgraph.
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                guard isEdge[idx], !isJunction[idx], !visited[idx] else { continue }
                if walkableNeighbors(x, y).count <= 1 {
                    chains.append(walkChain(fromX: x, fromY: y))
                }
            }
        }

        // Pass 2: closed loops — whatever non-junction pixels remain.
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                guard isEdge[idx], !isJunction[idx], !visited[idx] else { continue }
                var loop = walkChain(fromX: x, fromY: y)
                // Close the ring visually if the walk returned adjacent to start.
                if loop.count > 2,
                   let last = loop.last,
                   abs(last.x - loop[0].x) <= 1, abs(last.y - loop[0].y) <= 1 {
                    loop.append(loop[0])
                }
                chains.append(loop)
            }
        }

        return chains
            .filter { $0.count >= minChainPoints }
            .map { simplify($0, epsilon: simplifyEpsilon) }
    }

    /// Remove chain coverage from a density map so stipples don't double-draw
    /// the contours. Zeroes density within `radius` px of any chain segment.
    public static func subtractChains(
        from densityMap: DensityMap,
        chains: [[StipplePoint]],
        radius: Float = 1.5
    ) -> DensityMap {
        guard !chains.isEmpty else { return densityMap }
        var pixels = densityMap.pixels
        let width = densityMap.width
        let height = densityMap.height
        let r = Int(radius.rounded(.up))

        func clearAround(_ fx: Float, _ fy: Float) {
            let cx = Int(fx.rounded())
            let cy = Int(fy.rounded())
            for dy in -r...r {
                for dx in -r...r {
                    let x = cx + dx
                    let y = cy + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    let ddx = Float(x) - fx
                    let ddy = Float(y) - fy
                    if ddx * ddx + ddy * ddy <= radius * radius {
                        pixels[y * width + x] = 0
                    }
                }
            }
        }

        for chain in chains {
            guard chain.count >= 2 else {
                if let p = chain.first { clearAround(p.x, p.y) }
                continue
            }
            for i in 1..<chain.count {
                let a = chain[i - 1]
                let b = chain[i]
                let segLen = a.distance(to: b)
                let samples = max(1, Int((segLen / 0.5).rounded(.up)))
                for s in 0...samples {
                    let t = Float(s) / Float(samples)
                    clearAround(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
                }
            }
        }

        return DensityMap(width: width, height: height, pixels: pixels)
    }

    // MARK: — Douglas–Peucker simplification

    /// Iterative Douglas–Peucker (explicit stack — chains can be thousands
    /// of pixels long, so no recursion).
    static func simplify(_ pts: [StipplePoint], epsilon: Float) -> [StipplePoint] {
        guard pts.count > 2, epsilon > 0 else { return pts }
        var keep = [Bool](repeating: false, count: pts.count)
        keep[0] = true
        keep[pts.count - 1] = true

        var stack: [(lo: Int, hi: Int)] = [(0, pts.count - 1)]
        while let range = stack.popLast() {
            guard range.hi > range.lo + 1 else { continue }
            var maxDist: Float = -1
            var maxIdx = range.lo
            for i in (range.lo + 1)..<range.hi {
                let d = perpendicularDistance(pts[i], segA: pts[range.lo], segB: pts[range.hi])
                if d > maxDist {
                    maxDist = d
                    maxIdx = i
                }
            }
            if maxDist > epsilon {
                keep[maxIdx] = true
                stack.append((range.lo, maxIdx))
                stack.append((maxIdx, range.hi))
            }
        }

        var result = [StipplePoint]()
        result.reserveCapacity(pts.count / 4)
        for (i, p) in pts.enumerated() where keep[i] {
            result.append(p)
        }
        return result
    }

    /// Distance from `p` to segment a—b (falls back to point distance when
    /// the segment is degenerate, e.g. the endpoints of a closed loop).
    private static func perpendicularDistance(
        _ p: StipplePoint,
        segA a: StipplePoint,
        segB b: StipplePoint
    ) -> Float {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let lengthSquared = abx * abx + aby * aby
        guard lengthSquared > 1e-6 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared))
        let projX = a.x + t * abx
        let projY = a.y + t * aby
        let dx = p.x - projX
        let dy = p.y - projY
        return (dx * dx + dy * dy).squareRoot()
    }
}
