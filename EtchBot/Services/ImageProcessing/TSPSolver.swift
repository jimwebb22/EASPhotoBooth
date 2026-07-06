// TSPSolver.swift — EtchBot
// Traveling Salesman Problem solver for converting stipple points into
// a single continuous path.
//
// Algorithm:
//   Phase 1: Nearest-Neighbor construction (KD-tree, multiple distinct starts)
//   Phase 2: 2-opt improvement over precomputed k-nearest-neighbor candidate
//            lists, with an O(1) tour-position lookup (no linear scans)
//   Phase 3: Or-opt refinement (relocate segments of length 1–3, forward or
//            reversed, using O(1) incremental cost deltas)
//
// Performance target: <5 seconds for 3000 points on iPhone 12+.
// Pass `seed` for reproducible tours (tests); nil uses a random seed.

import Foundation

/// Progress update from the TSP solver.
public struct TSPSolverProgress: Sendable {
    public let phase: TSPPhase
    public let passNumber: Int
    public let improvement: Double  // tour length improvement this pass
    public let currentTourLength: Double
    public let progressFraction: Double  // 0.0–1.0
}

public enum TSPPhase: String, Sendable {
    case nearestNeighbor = "Building initial tour"
    case twoOpt          = "Optimizing tour (2-opt)"
    case orOpt           = "Refining tour"
    case complete        = "Tour complete"
}

public final class TSPSolver: Sendable {

    /// Number of nearest-neighbor candidates considered per node in the
    /// 2-opt and Or-opt improvement phases.
    private static let candidateCount = 12

    // MARK: — Public entry point

    /// Solve the TSP for the given stipple points.
    ///
    /// - Parameters:
    ///   - points: Stipple points from VoronoiStippler.
    ///   - settings: DrawingSettings (tspStartingPositions).
    ///   - seed: Optional RNG seed for reproducible results.
    ///   - progressHandler: Called on background thread.
    /// - Returns: Ordered array of point indices constituting the tour.
    public static func solve(
        points: [StipplePoint],
        settings: DrawingSettings,
        seed: UInt64? = nil,
        progressHandler: @Sendable ((TSPSolverProgress) -> Void)? = nil
    ) async -> [Int] {
        guard points.count >= 2 else {
            return Array(0..<points.count)
        }
        return await Task.detached(priority: .userInitiated) {
            let n = points.count
            let numStarts = max(1, min(settings.tspStartingPositions, n))
            let kdTree = KDTree(points: points)
            var rng = SeededRandomNumberGenerator(seed: seed ?? UInt64.random(in: UInt64.min...UInt64.max))

            // Precompute k-nearest-neighbor candidate lists (excluding self).
            let k = min(candidateCount, n - 1)
            var neighbors = [[Int]]()
            neighbors.reserveCapacity(n)
            for i in 0..<n {
                let near = kdTree.kNearest(to: points[i], k: k + 1).filter { $0 != i }
                neighbors.append(Array(near.prefix(k)))
            }

            // Phase 1: Nearest-Neighbor from multiple DISTINCT starts.
            let starts = Array(Array(0..<n).shuffled(using: &rng).prefix(numStarts))
            var bestTour: [Int] = []
            var bestLength: Double = .infinity

            for (attempt, startIndex) in starts.enumerated() {
                let tour = Self.nearestNeighborTour(points: points, kdTree: kdTree, startIndex: startIndex)
                let length = Self.tourLength(points: points, tour: tour)
                if length < bestLength {
                    bestLength = length
                    bestTour = tour
                }
                progressHandler?(TSPSolverProgress(
                    phase: .nearestNeighbor,
                    passNumber: attempt + 1,
                    improvement: 0,
                    currentTourLength: bestLength,
                    progressFraction: Double(attempt + 1) / Double(numStarts) * 0.25
                ))
                await Task.yield()
            }

            var tour = bestTour
            var position = [Int](repeating: 0, count: n)
            for (idx, node) in tour.enumerated() { position[node] = idx }
            var length = bestLength

            // Phase 2: 2-opt with candidate lists + position lookup.
            let maxTwoOptPasses = 30
            var pass = 0
            var improved = true
            while improved && pass < maxTwoOptPasses {
                pass += 1
                let passImprovement = Self.twoOptPass(
                    points: points, tour: &tour, position: &position, neighbors: neighbors
                )
                length -= passImprovement
                improved = passImprovement > 0.5
                progressHandler?(TSPSolverProgress(
                    phase: .twoOpt,
                    passNumber: pass,
                    improvement: passImprovement,
                    currentTourLength: length,
                    progressFraction: 0.25 + Double(pass) / Double(maxTwoOptPasses) * 0.55
                ))
                await Task.yield()
            }

            // Phase 3: Or-opt segment relocation (lengths 1–3).
            let maxOrOptRounds = 6
            var round = 0
            improved = true
            while improved && round < maxOrOptRounds {
                round += 1
                let roundImprovement = Self.orOptRound(
                    points: points, tour: &tour, position: &position, neighbors: neighbors
                )
                length -= roundImprovement
                improved = roundImprovement > 0.5
                progressHandler?(TSPSolverProgress(
                    phase: .orOpt,
                    passNumber: round,
                    improvement: roundImprovement,
                    currentTourLength: length,
                    progressFraction: 0.80 + Double(round) / Double(maxOrOptRounds) * 0.20
                ))
                await Task.yield()
            }

            progressHandler?(TSPSolverProgress(
                phase: .complete,
                passNumber: pass,
                improvement: 0,
                currentTourLength: length,
                progressFraction: 1.0
            ))

            return tour
        }.value
    }

    // MARK: — Nearest-Neighbor construction

    private static func nearestNeighborTour(
        points: [StipplePoint],
        kdTree: KDTree,
        startIndex: Int
    ) -> [Int] {
        let n = points.count
        var tour: [Int] = []
        tour.reserveCapacity(n)
        var visited = Set<Int>()
        visited.reserveCapacity(n)

        var current = startIndex
        tour.append(current)
        visited.insert(current)

        while tour.count < n {
            guard let next = kdTree.nearestIndex(to: points[current], excluding: visited) else { break }
            tour.append(next)
            visited.insert(next)
            current = next
        }

        return tour
    }

    // MARK: — 2-opt improvement pass

    /// One 2-opt pass. For each edge (a, b) = (tour[i], tour[i+1]), candidate
    /// re-connection points come from the k-nearest neighbors of both a and b;
    /// the candidate's tour index is found via the `position` lookup (O(1)).
    /// A swap reverses tour[i+1...j], replacing edges (a,b)+(c,d) with (a,c)+(b,d).
    /// Returns the total length improvement (positive).
    private static func twoOptPass(
        points: [StipplePoint],
        tour: inout [Int],
        position: inout [Int],
        neighbors: [[Int]]
    ) -> Double {
        let n = tour.count
        guard n >= 4 else { return 0 }
        var totalImprovement = 0.0

        for i in 0..<(n - 1) {
            let a = tour[i]
            let b = tour[i + 1]
            let ab = points[a].distance(to: points[b])

            var bestDelta: Float = -1e-3
            var bestJ = -1

            // Candidates where c = tour[j] is near a (new edge a—c).
            for c in neighbors[a] {
                let j = position[c]
                guard j > i + 1, j < n - 1 else { continue }
                let d = tour[j + 1]
                let delta = points[a].distance(to: points[c])
                          + points[b].distance(to: points[d])
                          - ab
                          - points[c].distance(to: points[d])
                if delta < bestDelta {
                    bestDelta = delta
                    bestJ = j
                }
            }
            // Candidates where d = tour[j+1] is near b (new edge b—d).
            for d in neighbors[b] {
                let j = position[d] - 1
                guard j > i + 1, j < n - 1 else { continue }
                let c = tour[j]
                let delta = points[a].distance(to: points[c])
                          + points[b].distance(to: points[d])
                          - ab
                          - points[c].distance(to: points[d])
                if delta < bestDelta {
                    bestDelta = delta
                    bestJ = j
                }
            }

            if bestJ >= 0 {
                reverseSegment(&tour, &position, i + 1, bestJ)
                totalImprovement += Double(-bestDelta)
            }
        }

        return totalImprovement
    }

    /// Reverse tour[lo...hi] in place, keeping `position` consistent.
    private static func reverseSegment(
        _ tour: inout [Int],
        _ position: inout [Int],
        _ lo: Int,
        _ hi: Int
    ) {
        var l = lo
        var h = hi
        while l < h {
            tour.swapAt(l, h)
            position[tour[l]] = l
            position[tour[h]] = h
            l += 1
            h -= 1
        }
    }

    // MARK: — Or-opt (segment relocation, lengths 1–3)

    /// One Or-opt round. Tries to relocate each segment of 1–3 consecutive
    /// nodes to a position adjacent to one of its endpoints' near neighbors,
    /// forward or reversed. All cost deltas are O(1); an accepted move costs
    /// O(n) for the array splice + position rebuild.
    /// Returns the total length improvement (positive).
    private static func orOptRound(
        points: [StipplePoint],
        tour: inout [Int],
        position: inout [Int],
        neighbors: [[Int]]
    ) -> Double {
        let n = tour.count
        guard n >= 5 else { return 0 }
        var totalImprovement = 0.0

        for segLen in 1...3 {
            guard n >= segLen + 3 else { continue }
            var s = 1
            while s + segLen < n {
                let p0 = tour[s - 1]
                let p1 = tour[s]                // segment head
                let p2 = tour[s + segLen - 1]   // segment tail
                let p3 = tour[s + segLen]

                // Gain from removing the segment and bridging p0—p3.
                let removeGain = points[p0].distance(to: points[p1])
                               + points[p2].distance(to: points[p3])
                               - points[p0].distance(to: points[p3])
                if removeGain > 1e-3 {
                    var bestDelta: Float = -1e-3
                    var bestJ = -1
                    var bestReversed = false

                    for endpoint in [p1, p2] {
                        for c in neighbors[endpoint] {
                            let j = position[c]
                            // Insertion is between tour[j] and tour[j+1]; skip
                            // positions inside or immediately before the segment.
                            guard j < n - 1, j < s - 1 || j >= s + segLen else { continue }
                            let q0 = tour[j]
                            let q1 = tour[j + 1]
                            let bridge = points[q0].distance(to: points[q1])
                            // Forward: q0 → p1 … p2 → q1
                            let deltaF = points[q0].distance(to: points[p1])
                                       + points[p2].distance(to: points[q1])
                                       - bridge - removeGain
                            if deltaF < bestDelta {
                                bestDelta = deltaF; bestJ = j; bestReversed = false
                            }
                            // Reversed: q0 → p2 … p1 → q1
                            let deltaR = points[q0].distance(to: points[p2])
                                       + points[p1].distance(to: points[q1])
                                       - bridge - removeGain
                            if deltaR < bestDelta {
                                bestDelta = deltaR; bestJ = j; bestReversed = true
                            }
                        }
                    }

                    if bestJ >= 0 {
                        var segment = Array(tour[s..<(s + segLen)])
                        if bestReversed { segment.reverse() }
                        tour.removeSubrange(s..<(s + segLen))
                        let insertAt = (bestJ < s ? bestJ : bestJ - segLen) + 1
                        tour.insert(contentsOf: segment, at: insertAt)
                        for (idx, node) in tour.enumerated() { position[node] = idx }
                        totalImprovement += Double(-bestDelta)
                    }
                }
                s += 1
            }
        }

        return totalImprovement
    }

    // MARK: — Tour length calculation

    /// Length of the CLOSED tour (includes the wrap-around edge).
    public static func tourLength(points: [StipplePoint], tour: [Int]) -> Double {
        guard tour.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<(tour.count - 1) {
            total += Double(points[tour[i]].distance(to: points[tour[i + 1]]))
        }
        total += Double(points[tour.last!].distance(to: points[tour.first!]))
        return total
    }

    // MARK: — Break the closed tour into the drawn open path

    /// Break the closed tour at its LONGEST edge (including the wrap-around
    /// edge), so the ugliest jump line is the one that is never drawn.
    /// Returns the tour rotated to start just after the dropped edge.
    public static func breakTourAtLongestEdge(tour: [Int], points: [StipplePoint]) -> [Int] {
        guard tour.count >= 2 else { return tour }
        var worstEdgeStart = tour.count - 1  // default: wrap-around edge
        var worstLength: Float = -1
        for i in 0..<tour.count {
            let a = points[tour[i]]
            let b = points[tour[(i + 1) % tour.count]]
            let d = a.distance(to: b)
            if d > worstLength {
                worstLength = d
                worstEdgeStart = i
            }
        }
        let start = (worstEdgeStart + 1) % tour.count
        guard start != 0 else { return tour }
        return Array(tour[start...] + tour[..<start])
    }

    /// Break the closed tour at the point nearest to the home corner (0, 0).
    /// Kept for compatibility; `breakTourAtLongestEdge` usually yields a
    /// better drawing because the dropped edge is the worst one.
    public static func breakTourNearHome(tour: [Int], points: [StipplePoint]) -> [Int] {
        guard !tour.isEmpty else { return tour }
        let homePoint = StipplePoint(x: 0, y: 0)
        var closestIdx = 0
        var closestDist = points[tour[0]].distance(to: homePoint)
        for i in 1..<tour.count {
            let d = points[tour[i]].distance(to: homePoint)
            if d < closestDist {
                closestDist = d
                closestIdx = i
            }
        }
        return Array(tour[closestIdx...] + tour[..<closestIdx])
    }
}
