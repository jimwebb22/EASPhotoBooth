// VoronoiStippler.swift — EtchBot
// Weighted Voronoi Stippling (Secord's Algorithm).
//
// Pipeline:
//   1. Rejection sampling: place up to N points with probability ∝ density.
//      Zero-density (blank) regions NEVER receive points — settings.pointCount
//      is an upper bound, not an exact count.
//   2. Lloyd's relaxation (40 iterations or until convergence):
//      a. Build KD-tree over current point positions.
//      b. Compute density-weighted Voronoi centroids (pixel-based).
//      c. Move each point to its cell centroid.
//      d. DROP orphan cells (zero-density cells) — re-seeding them would
//         put dots back into blank regions and draw scribbles across them.
//   3. Return ordered array of StipplePoint in Etch-a-Sketch drawing space.
//
// Performance target: <3 seconds for 3000 points on iPhone 12+.
// Uses async/await for non-blocking progress reporting.

import Foundation

/// Progress update from the stippler.
public struct StipplingProgress: Sendable {
    public let iteration: Int
    public let totalIterations: Int
    public let averageDisplacement: Float
    public let phase: StipplingPhase
}

public enum StipplingPhase: String, Sendable {
    case initialPlacement = "Placing initial dots"
    case relaxing = "Optimizing distribution"
    case complete = "Complete"
}

public final class VoronoiStippler: Sendable {

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
        progressHandler: @Sendable ((StipplingProgress) -> Void)? = nil
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
                guard !points.isEmpty else { break }
                let voronoiResult = VoronoiDiagram.computeWeightedCentroids(
                    points: points,
                    densityMap: densityMap
                )

                // Move each point to its cell centroid; DROP orphan cells
                // (cells with zero total density) instead of re-seeding them.
                var newPoints: [StipplePoint] = []
                newPoints.reserveCapacity(points.count)
                var totalDisp: Float = 0
                for i in 0..<points.count {
                    if let centroid = voronoiResult.centroids[i] {
                        totalDisp += points[i].distance(to: centroid)
                        newPoints.append(centroid)
                    }
                }
                points = newPoints
                let avgDisp = points.isEmpty ? 0 : totalDisp / Float(points.count)

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

    /// Sample up to `count` points with probability strictly proportional to
    /// density. No acceptance floor and no uniform fallback: blank regions
    /// get NO points, and a sparse image simply yields fewer points.
    private static func rejectionSample(densityMap: DensityMap, count: Int) -> [StipplePoint] {
        var points: [StipplePoint] = []
        points.reserveCapacity(count)
        let w = densityMap.width
        let h = densityMap.height
        // Find max density for rejection criterion
        var maxDensity: Float = 0
        for v in densityMap.pixels { if v > maxDensity { maxDensity = v } }
        guard maxDensity > 0 else { return [] }  // fully blank image
        var attempts = 0
        let maxAttempts = count * 200

        while points.count < count && attempts < maxAttempts {
            attempts += 1
            let fx = Float.random(in: 0..<Float(w))
            let fy = Float.random(in: 0..<Float(h))
            let density = densityMap.interpolate(fx: fx, fy: fy) / maxDensity
            if density > 0, Float.random(in: 0..<1) < density {
                points.append(StipplePoint(x: fx, y: fy))
            }
        }

        return points
    }
}
