// VoronoiStippler.swift — EtchBot
// Weighted Voronoi Stippling (Secord's Algorithm).
//
// Pipeline:
//   1. Rejection sampling: place N points with probability ∝ density.
//   2. Lloyd's relaxation (40 iterations or until convergence):
//      a. Build KD-tree over current point positions.
//      b. Compute density-weighted Voronoi centroids (pixel-based).
//      c. Move each point to its cell centroid.
//      d. Re-sample orphan cells (zero-density cells) uniformly.
//   3. Return ordered array of StipplePoint in Etch-a-Sketch drawing space.
//
// Performance target: <3 seconds for 3000 points, <15 seconds for 15000 points on iPhone 12+.
// Uses async/await for non-blocking progress reporting.

import Foundation

/// Progress update from the stippler.
nonisolated public struct StipplingProgress: Sendable {
    public let iteration: Int
    public let totalIterations: Int
    public let averageDisplacement: Float
    public let phase: StipplingPhase
}

nonisolated public enum StipplingPhase: String, Sendable {
    case initialPlacement = "Placing initial dots"
    case relaxing = "Optimizing distribution"
    case complete = "Complete"
}

nonisolated public final class VoronoiStippler: Sendable {

    // MARK: — Public entry point

    /// Generate stipple points from a density map.
    ///
    /// - Parameters:
    ///   - densityMap: Output from ImagePreprocessor.
    ///   - settings: DrawingSettings (pointCount, voronoiIterations).
    ///   - progressHandler: Called on background thread with iteration progress.
    /// - Returns: Array of StipplePoint in density-map coordinate space.
    public static func stipple(
        densityMap: DensityMap,
        settings: DrawingSettings,
        progressHandler: (@Sendable (StipplingProgress) -> Void)? = nil
    ) async -> [StipplePoint] {
        let n = settings.pointCount
        let maxIterations = settings.voronoiIterations
        let convergenceThreshold: Float = 0.5

        return await Task.detached(priority: .userInitiated) {
            // Phase 1: Initial placement via rejection sampling
            progressHandler?(StipplingProgress(
                iteration: 0,
                totalIterations: maxIterations,
                averageDisplacement: Float.infinity,
                phase: .initialPlacement
            ))
            var points = Self.rejectionSample(densityMap: densityMap, count: n)

            // Phase 2: Lloyd's relaxation
            for iter in 0..<maxIterations {
                let oldPoints = points
                let voronoiResult = VoronoiDiagram.computeWeightedCentroids(
                    points: points,
                    densityMap: densityMap
                )

                // Move to centroids; re-sample orphans
                for i in 0..<n {
                    if let centroid = voronoiResult.centroids[i] {
                        points[i] = centroid
                    } else {
                        // Orphan cell: re-sample from density map
                        points[i] = Self.singleRejectionSample(densityMap: densityMap)
                            ?? StipplePoint(
                                x: Float.random(in: 0..<Float(densityMap.width)),
                                y: Float.random(in: 0..<Float(densityMap.height))
                            )
                    }
                }

                // Compute convergence
                var totalDisp: Float = 0
                for i in 0..<n { totalDisp += oldPoints[i].distance(to: points[i]) }
                let avgDisp = totalDisp / Float(n)

                progressHandler?(StipplingProgress(
                    iteration: iter + 1,
                    totalIterations: maxIterations,
                    averageDisplacement: avgDisp,
                    phase: .relaxing
                ))

                if avgDisp < convergenceThreshold {
                    break
                }

                // Yield periodically to avoid blocking
                if iter % 5 == 0 {
                    await Task.yield()
                }
            }

            progressHandler?(StipplingProgress(
                iteration: maxIterations,
                totalIterations: maxIterations,
                averageDisplacement: 0,
                phase: .complete
            ))

            return points
        }.value
    }

    // MARK: — Rejection sampling

    /// Sample N points from a density map using rejection sampling.
    private static func rejectionSample(densityMap: DensityMap, count: Int) -> [StipplePoint] {
        var points: [StipplePoint] = []
        points.reserveCapacity(count)
        let w = densityMap.width
        let h = densityMap.height
        // Find max density for rejection criterion
        var maxDensity: Float = 0
        for v in densityMap.pixels { if v > maxDensity { maxDensity = v } }
        let normaliser: Float = maxDensity > 0 ? maxDensity : 1
        var attempts = 0
        let maxAttempts = count * 100

        while points.count < count && attempts < maxAttempts {
            attempts += 1
            let fx = Float.random(in: 0..<Float(w))
            let fy = Float.random(in: 0..<Float(h))
            let density = densityMap.interpolate(fx: fx, fy: fy) / normaliser
            let threshold = max(density, 0.02) // minimum 2% chance to fill sparse images
            if Float.random(in: 0..<1) < threshold {
                points.append(StipplePoint(x: fx, y: fy))
            }
        }

        // If rejection sampling didn't get enough points (very sparse image),
        // fill remaining slots uniformly.
        while points.count < count {
            points.append(StipplePoint(
                x: Float.random(in: 0..<Float(w)),
                y: Float.random(in: 0..<Float(h))
            ))
        }

        return points
    }

    /// Sample a single point. Returns nil if all attempts fail.
    private static func singleRejectionSample(densityMap: DensityMap) -> StipplePoint? {
        let w = densityMap.width; let h = densityMap.height
        var maxDensity: Float = 0
        for v in densityMap.pixels { if v > maxDensity { maxDensity = v } }
        let normaliser: Float = maxDensity > 0 ? maxDensity : 1
        for _ in 0..<200 {
            let fx = Float.random(in: 0..<Float(w))
            let fy = Float.random(in: 0..<Float(h))
            let density = densityMap.interpolate(fx: fx, fy: fy) / normaliser
            if Float.random(in: 0..<1) < max(density, 0.05) {
                return StipplePoint(x: fx, y: fy)
            }
        }
        return nil
    }
}
