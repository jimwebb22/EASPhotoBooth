// VoronoiDiagram.swift — EtchBot
// Discrete pixel-based Voronoi diagram computation via the Jump Flooding
// Algorithm (JFA).
//
// For the stipple count ranges used (500–10000 points over a ~500×343 grid),
// JFA assigns every pixel to its nearest stipple point in O(N log N) with
// cache-friendly linear sweeps — roughly an order of magnitude faster than
// the previous per-pixel KD-tree queries, which matters because Lloyd's
// relaxation recomputes the assignment up to 40 times per image.
//
// Algorithm:
//   1. Seed: write each point's index into the pixel it occupies.
//   2. Flood passes with step sizes N/2, N/4, …, 1 (ping-pong buffers):
//      each pixel adopts the best (nearest-site) label among its 8 neighbors
//      at the current step offset.
//   3. A final step-1 pass ("JFA+1") cleans up the rare misassignments the
//      plain schedule leaves behind.
//   4. Accumulate density-weighted centroids per label.

import Foundation

/// Result of one Voronoi relaxation pass.
public struct VoronoiCentroids {
    /// For each stipple point index, the density-weighted centroid position.
    /// Nil if the cell had zero density (orphan point — will be dropped).
    public let centroids: [StipplePoint?]
}

public final class VoronoiDiagram: Sendable {

    /// Compute density-weighted Voronoi centroids for a set of stipple points.
    ///
    /// - Parameters:
    ///   - points: Current stipple point positions.
    ///   - densityMap: The density map (0 = blank, 1 = max density).
    /// - Returns: VoronoiCentroids with weighted centroid for each cell.
    public static func computeWeightedCentroids(
        points: [StipplePoint],
        densityMap: DensityMap
    ) -> VoronoiCentroids {
        let n = points.count
        guard n > 0 else { return VoronoiCentroids(centroids: []) }
        let width = densityMap.width
        let height = densityMap.height

        let labels = assignPixels(points: points, width: width, height: height)

        // Accumulate density-weighted centroid sums per cell.
        var sumX = [Double](repeating: 0, count: n)
        var sumY = [Double](repeating: 0, count: n)
        var sumW = [Double](repeating: 0, count: n)

        for py in 0..<height {
            for px in 0..<width {
                let density = densityMap.value(x: px, y: py)
                // Zero-density pixels contribute nothing: cells that cover
                // only blank pixels become orphans (nil centroid) and the
                // stippler drops them, keeping dots out of blank regions.
                guard density > 0 else { continue }
                let label = Int(labels[py * width + px])
                guard label >= 0 else { continue }
                let weight = Double(density)
                sumX[label] += Double(px) * weight
                sumY[label] += Double(py) * weight
                sumW[label] += weight
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

    /// Nearest-site label for every pixel, via jump flooding.
    /// Exposed internally so tests can compare against brute force.
    static func assignPixels(
        points: [StipplePoint],
        width: Int,
        height: Int
    ) -> [Int32] {
        let pixelCount = width * height
        var labels = [Int32](repeating: -1, count: pixelCount)
        var bestDist = [Float](repeating: .infinity, count: pixelCount)

        // Flat coordinate arrays for cache-friendly distance evaluation.
        let xs = points.map(\.x)
        let ys = points.map(\.y)

        // 1. Seed each site into the nearest FREE pixel (searching a small
        //    neighborhood when several sites round to the same pixel), so
        //    near-coincident sites don't lose their label entirely and get
        //    spuriously dropped as orphans.
        let seedOffsets: [(dx: Int, dy: Int)] = {
            var offsets: [(dx: Int, dy: Int)] = []
            for dy in -2...2 {
                for dx in -2...2 { offsets.append((dx, dy)) }
            }
            return offsets.sorted { ($0.dx * $0.dx + $0.dy * $0.dy) < ($1.dx * $1.dx + $1.dy * $1.dy) }
        }()

        for i in 0..<points.count {
            let px = max(0, min(width - 1, Int(xs[i].rounded())))
            let py = max(0, min(height - 1, Int(ys[i].rounded())))
            for offset in seedOffsets {
                let sx = px + offset.dx
                let sy = py + offset.dy
                guard sx >= 0, sx < width, sy >= 0, sy < height else { continue }
                let idx = sy * width + sx
                guard labels[idx] < 0 else { continue }
                let dx = Float(sx) - xs[i]
                let dy = Float(sy) - ys[i]
                labels[idx] = Int32(i)
                bestDist[idx] = dx * dx + dy * dy
                break
            }
            // If every pixel within radius 2 is taken (pathologically dense
            // cluster), the site goes unseeded and is dropped as an orphan.
        }

        // 2. Flood passes: N/2, N/4, …, 2, 1, then a final 1 (JFA+1).
        var readLabels = labels
        var readDist = bestDist
        var writeLabels = labels
        var writeDist = bestDist

        var step = 1
        while step * 2 < max(width, height) { step *= 2 }

        var steps: [Int] = []
        while step >= 1 {
            steps.append(step)
            step /= 2
        }
        steps.append(1)  // JFA+1 cleanup pass

        for s in steps {
            for y in 0..<height {
                for x in 0..<width {
                    let idx = y * width + x
                    var bestLabel = readLabels[idx]
                    var best = readDist[idx]
                    for dy in [-s, 0, s] {
                        let ny = y + dy
                        guard ny >= 0, ny < height else { continue }
                        for dx in [-s, 0, s] {
                            let nx = x + dx
                            guard nx >= 0, nx < width else { continue }
                            let neighborLabel = readLabels[ny * width + nx]
                            guard neighborLabel >= 0 else { continue }
                            let i = Int(neighborLabel)
                            let ddx = Float(x) - xs[i]
                            let ddy = Float(y) - ys[i]
                            let d = ddx * ddx + ddy * ddy
                            if d < best {
                                best = d
                                bestLabel = neighborLabel
                            }
                        }
                    }
                    writeLabels[idx] = bestLabel
                    writeDist[idx] = best
                }
            }
            swap(&readLabels, &writeLabels)
            swap(&readDist, &writeDist)
        }

        return readLabels
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
