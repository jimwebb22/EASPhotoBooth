// TSPSolver.swift — EtchBot
// Traveling Salesman Problem solver for converting stipple points into
// a single continuous path.
//
// Algorithm:
//   Phase 1: Nearest-Neighbor construction (with KD-tree, multiple starts)
//   Phase 2: 2-opt improvement (with KD-tree pruning)
//   Phase 3: Or-opt refinement (1-move relocation)
//
// Performance target: <5 seconds for 3000 points on iPhone 12+.
// Reports progress via AsyncStream.

import Foundation

/// Progress update from the TSP solver.
nonisolated public struct TSPSolverProgress: Sendable {
    public let phase: TSPPhase
    public let passNumber: Int
    public let improvement: Double  // tour length improvement this pass
    public let currentTourLength: Double
    public let progressFraction: Double  // 0.0–1.0
}

nonisolated public enum TSPPhase: String, Sendable {
    case nearestNeighbor = "Building initial tour"
    case twoOpt          = "Optimizing tour (2-opt)"
    case orOpt           = "Refining tour"
    case complete        = "Tour complete"
}

nonisolated public final class TSPSolver: Sendable {

    // MARK: — Public entry point

    /// Solve the TSP for the given stipple points.
    ///
    /// - Parameters:
    ///   - points: Stipple points from VoronoiStippler.
    ///   - settings: DrawingSettings (tspStartingPositions).
    ///   - progressHandler: Called on background thread.
    /// - Returns: Ordered array of point indices constituting the tour.
    public static func solve(
        points: [StipplePoint],
        settings: DrawingSettings,
        progressHandler: (@Sendable (TSPSolverProgress) -> Void)? = nil
    ) async -> [Int] {
        guard points.count >= 2 else {
            return Array(0..<points.count)
        }
        return await Task.detached(priority: .userInitiated) {
            let n = points.count
            let numStarts = min(settings.tspStartingPositions, n)
            let kdTree = KDTree(points: points)

            // Phase 1: Nearest-Neighbor from multiple starts
            var bestTour: [Int] = []
            var bestLength: Double = .infinity

            for startIdx in 0..<numStarts {
                let startPoint = Int.random(in: 0..<n)
                let tour = Self.nearestNeighborTour(points: points, kdTree: kdTree, startIndex: startPoint)
                let length = Self.tourLength(points: points, tour: tour)
                if length < bestLength {
                    bestLength = length
                    bestTour = tour
                }
                progressHandler?(TSPSolverProgress(
                    phase: .nearestNeighbor,
                    passNumber: startIdx + 1,
                    improvement: 0,
                    currentTourLength: bestLength,
                    progressFraction: Double(startIdx + 1) / Double(numStarts) * 0.3
                ))
                await Task.yield()
            }

            // Phase 2: 2-opt improvement — time budget scales with point count
            // 3000 pts → 10s, 10000 pts → 20s, 15000 pts → 30s, 20000 pts → 40s
            let maxPasses = 30
            let twoOptSeconds = max(10, min(60, n / 500))
            let twoOptDeadline = ContinuousClock.now + .seconds(twoOptSeconds)
            let neighborCount = min(40, max(20, n / 200))
            var improved = true
            var pass = 0
            var prevLength = bestLength

            while improved && pass < maxPasses && ContinuousClock.now < twoOptDeadline {
                improved = false
                pass += 1
                let (newTour, newLength) = Self.twoOptPass(points: points, tour: bestTour, kdTree: kdTree, neighborCount: neighborCount)
                if newLength < bestLength - 0.001 {
                    bestTour = newTour
                    bestLength = newLength
                    improved = true
                }
                let imp = prevLength - bestLength
                prevLength = bestLength
                progressHandler?(TSPSolverProgress(
                    phase: .twoOpt,
                    passNumber: pass,
                    improvement: imp,
                    currentTourLength: bestLength,
                    progressFraction: 0.3 + Double(pass) / Double(maxPasses) * 0.6
                ))
                await Task.yield()
            }

            // Phase 3: Or-opt (relocate single nodes)
            let (refinedTour, refinedLength) = Self.orOpt(points: points, tour: bestTour, kdTree: kdTree)
            bestTour = refinedTour
            bestLength = refinedLength

            progressHandler?(TSPSolverProgress(
                phase: .complete,
                passNumber: pass,
                improvement: prevLength - bestLength,
                currentTourLength: bestLength,
                progressFraction: 1.0
            ))

            return bestTour
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

    /// One full 2-opt pass using KD-tree pruning.
    /// For each edge (tour[i], tour[i+1]), checks neighbours of tour[i]
    /// as candidate j endpoints to avoid O(n²) full scan.
    /// Uses a position map for O(1) point→index lookup instead of firstIndex(of:).
    private static func twoOptPass(
        points: [StipplePoint],
        tour: [Int],
        kdTree: KDTree,
        neighborCount: Int = 20
    ) -> ([Int], Double) {
        let n = tour.count
        var improved = tour
        var length = tourLength(points: points, tour: improved)

        // Build position map: pointIndex → tour position (O(1) lookup)
        var position = [Int](repeating: 0, count: points.count)
        for i in 0..<n {
            position[improved[i]] = i
        }

        outer: for i in 0..<(n - 1) {
            let a = improved[i]
            let b = improved[i + 1]
            let ab = points[a].distance(to: points[b])

            // Check nearest neighbours of a as potential j (scaled with point count)
            let neighbours = kdTree.kNearest(to: points[a], k: neighborCount)
            for candidateIdx in neighbours {
                let j = position[candidateIdx]
                guard j > i + 1, j < n - 1 else { continue }

                let c = improved[j]
                let d = improved[j + 1]
                // Cost before: |ab| + |cd|; cost after swap: |ac| + |bd|
                let cd = points[c].distance(to: points[d])
                let ac = points[a].distance(to: points[c])
                let bd = points[b].distance(to: points[d])

                if ac + bd < ab + cd - 0.001 {
                    // Reverse the segment between i+1 and j
                    improved[(i + 1)...j].reverse()
                    length = length - Double(ab + cd) + Double(ac + bd)
                    // Update position map for the reversed segment
                    for k in (i + 1)...j {
                        position[improved[k]] = k
                    }
                    continue outer
                }
            }
        }

        return (improved, length)
    }

    // MARK: — Or-opt (single node relocation)

    /// Relocate individual nodes to better positions using delta-based cost evaluation.
    /// Uses KD-tree to find candidate insertion positions instead of brute-force.
    /// Position map provides O(1) lookup instead of O(n) firstIndex(of:).
    private static func orOpt(points: [StipplePoint], tour: [Int], kdTree: KDTree) -> ([Int], Double) {
        let n = tour.count
        guard n >= 4 else { return (tour, tourLength(points: points, tour: tour)) }
        var best = tour
        var bestLen = tourLength(points: points, tour: best)

        // Build position map: pointIndex → tour position
        var position = [Int](repeating: 0, count: points.count)
        for i in 0..<n { position[best[i]] = i }

        let orOptNeighborCount = min(15, max(10, n / 500))
        var madeImprovement = true
        var iterations = 0
        while madeImprovement && iterations < 5 {
            madeImprovement = false
            iterations += 1
            for i in 1..<(n - 1) {
                let node = best[i]
                let prev = best[i - 1]
                let next = best[i + 1]

                // Cost of removing node from its current position
                let removeCost = Double(points[prev].distance(to: points[node]))
                    + Double(points[node].distance(to: points[next]))
                let directCost = Double(points[prev].distance(to: points[next]))
                let removalSaving = removeCost - directCost

                // Only try reinserting near KD-tree neighbours of the node
                let neighbours = kdTree.kNearest(to: points[node], k: orOptNeighborCount)
                var bestInsertCost = Double.infinity
                var bestInsertPos = -1

                for candidateIdx in neighbours {
                    let pos = position[candidateIdx]
                    guard pos != i, pos != i - 1, pos < n - 1 else { continue }

                    let edgeStart = best[pos]
                    let edgeEnd = best[pos + 1]
                    // Cost of inserting node between edgeStart and edgeEnd
                    let oldEdge = Double(points[edgeStart].distance(to: points[edgeEnd]))
                    let newEdge = Double(points[edgeStart].distance(to: points[node]))
                        + Double(points[node].distance(to: points[edgeEnd]))
                    let insertionCost = newEdge - oldEdge

                    if insertionCost < bestInsertCost {
                        bestInsertCost = insertionCost
                        bestInsertPos = pos
                    }
                }

                // Apply if net improvement
                if bestInsertPos >= 0 && bestInsertCost < removalSaving - 0.001 {
                    // Remove from current position, insert at best position
                    best.remove(at: i)
                    // Adjust insertion index if it was after the removal point
                    let insertAt = bestInsertPos >= i ? bestInsertPos : bestInsertPos + 1
                    best.insert(node, at: insertAt)
                    bestLen = bestLen - removalSaving + bestInsertCost
                    madeImprovement = true
                    // Rebuild position map after mutation
                    for j in 0..<n { position[best[j]] = j }
                }
            }
        }

        return (best, bestLen)
    }

    // MARK: — Tour length calculation

    public static func tourLength(points: [StipplePoint], tour: [Int]) -> Double {
        guard tour.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<(tour.count - 1) {
            total += Double(points[tour[i]].distance(to: points[tour[i + 1]]))
        }
        // Add closing edge (last → first)
        total += Double(points[tour.last!].distance(to: points[tour.first!]))
        return total
    }

    // MARK: — Break tour near home corner

    /// Break the closed tour at the point nearest to the home corner (0, 0),
    /// so the drawing starts and ends close to home.
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
        // Rotate tour so it starts at closestIdx
        return Array(tour[closestIdx...] + tour[..<closestIdx])
    }
}
