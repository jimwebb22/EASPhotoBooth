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
        progressHandler: @Sendable ((TSPSolverProgress) -> Void)? = nil
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

            // Phase 2: 2-opt improvement
            let maxPasses = 50
            var improved = true
            var pass = 0
            var prevLength = bestLength

            while improved && pass < maxPasses {
                improved = false
                pass += 1
                let (newTour, newLength) = Self.twoOptPass(points: points, tour: bestTour, kdTree: kdTree)
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
            let (refinedTour, refinedLength) = Self.orOpt(points: points, tour: bestTour)
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
    private static func twoOptPass(
        points: [StipplePoint],
        tour: [Int],
        kdTree: KDTree
    ) -> ([Int], Double) {
        let n = tour.count
        var improved = tour
        var length = tourLength(points: points, tour: improved)

        outer: for i in 0..<(n - 1) {
            let a = improved[i]
            let b = improved[i + 1]
            let ab = points[a].distance(to: points[b])

            // Only check the nearest 20 neighbours of a as potential j
            let neighbours = kdTree.kNearest(to: points[a], k: 20)
            for candidateIdx in neighbours {
                guard let j = improved.firstIndex(of: candidateIdx),
                      j > i + 1,
                      j < n - 1 else { continue }

                let c = improved[j]
                let d = improved[j + 1]
                // Cost before: |ab| + |cd|; cost after swap: |ac| + |bd|
                let cd = points[c].distance(to: points[d])
                let ac = points[a].distance(to: points[c])
                let bd = points[b].distance(to: points[d])

                if ac + bd < ab + cd - 0.001 {
                    // Reverse the segment between i+1 and j
                    let sub = Array(improved[(i + 1)...j].reversed())
                    improved.replaceSubrange((i + 1)...j, with: sub)
                    length = length - Double(ab + cd) + Double(ac + bd)
                    continue outer
                }
            }
        }

        return (improved, length)
    }

    // MARK: — Or-opt (single node relocation)

    private static func orOpt(points: [StipplePoint], tour: [Int]) -> ([Int], Double) {
        let n = tour.count
        var best = tour
        var bestLen = tourLength(points: points, tour: best)

        var madeImprovement = true
        var iterations = 0
        while madeImprovement && iterations < 10 {
            madeImprovement = false
            iterations += 1
            for i in 1..<(n - 1) {
                let node = best[i]
                var trial = best
                trial.remove(at: i)
                // Try inserting at each position
                for j in 1..<(n - 1) where j != i {
                    var candidate = trial
                    candidate.insert(node, at: j)
                    let len = tourLength(points: points, tour: candidate)
                    if len < bestLen - 0.001 {
                        best = candidate
                        bestLen = len
                        madeImprovement = true
                        break
                    }
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
