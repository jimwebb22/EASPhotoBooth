// VoronoiDiagram.swift — EtchBot
// Discrete pixel-based Voronoi diagram computation.
//
// For the stipple count ranges used (500–6000 points over a 500×320 grid),
// a pixel-based approach accelerated by a KD-tree provides the best balance of
// correctness, performance, and implementation simplicity on iOS.
//
// Algorithm:
//   For each pixel (x, y), find the nearest stipple point using the KD-tree.
//   Record the nearest-point assignment and the pixel's contribution to that
//   cell's weighted centroid.
//
// This replaces Fortune's sweep-line algorithm with an equally correct but
// simpler pixel-counting approach that integrates directly with the density
// map for weighted-centroid computation.

import Foundation

/// Result of one Voronoi relaxation pass.
nonisolated public struct VoronoiCentroids {
    /// For each stipple point index, the density-weighted centroid position.
    /// Nil if the cell had zero density (orphan point — will be resampled).
    public let centroids: [StipplePoint?]
}

nonisolated public final class VoronoiDiagram: Sendable {

    /// Compute density-weighted Voronoi centroids for a set of stipple points.
    ///
    /// - Parameters:
    ///   - points: Current stipple point positions.
    ///   - densityMap: The density map (0=white, 1=black).
    ///   - width: Working resolution width.
    ///   - height: Working resolution height.
    /// - Returns: VoronoiCentroids with weighted centroid for each cell.
    public static func computeWeightedCentroids(
        points: [StipplePoint],
        densityMap: DensityMap
    ) -> VoronoiCentroids {
        let n = points.count
        let width = densityMap.width
        let height = densityMap.height

        let kdTree = KDTree(points: points)

        // Accumulators per stipple point: (sumWeightedX, sumWeightedY, sumWeight)
        var sumX = [Double](repeating: 0, count: n)
        var sumY = [Double](repeating: 0, count: n)
        var sumW = [Double](repeating: 0, count: n)

        for py in 0..<height {
            for px in 0..<width {
                let density = densityMap.value(x: px, y: py)
                // Small background density keeps all cells alive
                let weight = Double(max(density, 0.01))
                let query = StipplePoint(x: Float(px), y: Float(py))
                guard let nearestIdx = kdTree.nearestIndex(to: query) else { continue }
                sumX[nearestIdx] += Double(px) * weight
                sumY[nearestIdx] += Double(py) * weight
                sumW[nearestIdx] += weight
            }
        }

        var centroids = [StipplePoint?](repeating: nil, count: n)
        for i in 0..<n {
            if sumW[i] > 0 {
                centroids[i] = StipplePoint(
                    x: Float(sumX[i] / sumW[i]),
                    y: Float(sumY[i] / sumW[i])
                )
            }
        }

        return VoronoiCentroids(centroids: centroids)
    }

    /// Check convergence: returns true if average point displacement < threshold.
    public static func hasConverged(
        old: [StipplePoint],
        new: [StipplePoint],
        threshold: Float = 0.5
    ) -> Bool {
        guard old.count == new.count else { return false }
        var totalDisplacement: Float = 0
        for i in 0..<old.count {
            totalDisplacement += old[i].distance(to: new[i])
        }
        return (totalDisplacement / Float(old.count)) < threshold
    }
}
