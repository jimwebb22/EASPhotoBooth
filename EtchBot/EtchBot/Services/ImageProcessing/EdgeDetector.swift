// EdgeDetector.swift — EtchBot
// Canny edge detection implemented via vDSP convolution.
//
// Simplified Canny pipeline:
//   1. Gaussian blur (noise reduction)
//   2. Sobel gradient magnitude
//   3. Non-maximum suppression (thin edges to 1px)
//   4. Double-threshold hysteresis

import Foundation
import Accelerate

nonisolated public enum EdgeDetectorError: Error {
    case invalidDimensions
}

nonisolated public final class EdgeDetector: Sendable {

    // MARK: — Public entry point

    /// Run Canny edge detection on a Float32 grayscale pixel array.
    /// - Parameters:
    ///   - pixels: Row-major Float32 array, 0=black, 1=white, width×height.
    ///   - width: Image width.
    ///   - height: Image height.
    ///   - lowThreshold: Hysteresis low threshold (default 0.05).
    ///   - highThreshold: Hysteresis high threshold (default 0.15).
    /// - Returns: Edge map Float32 array, same dimensions, 0=no edge, 1=edge.
    public static func canny(
        pixels: [Float],
        width: Int,
        height: Int,
        lowThreshold: Float = 0.05,
        highThreshold: Float = 0.15
    ) throws -> [Float] {
        guard pixels.count == width * height, width > 4, height > 4 else {
            throw EdgeDetectorError.invalidDimensions
        }
        // 1. Gaussian blur
        let blurred = gaussianBlur(pixels: pixels, width: width, height: height, radius: 2)
        // 2. Sobel gradients
        let (gx, gy, magnitude) = sobelGradients(pixels: blurred, width: width, height: height)
        // 3. Non-maximum suppression
        let suppressed = nonMaxSuppression(gx: gx, gy: gy, magnitude: magnitude, width: width, height: height)
        // 4. Hysteresis thresholding
        return hysteresis(magnitude: suppressed, width: width, height: height, low: lowThreshold, high: highThreshold)
    }

    /// Multi-scale Canny edge detection.
    /// Runs edge detection at two scales (fine σ≈1.0 and coarse σ≈2.0) and merges
    /// the results. The coarse pass captures broad structural edges (outlines) while
    /// the fine pass captures detail edges (textures, veins).
    public static func multiScaleCanny(
        pixels: [Float],
        width: Int,
        height: Int
    ) throws -> [Float] {
        guard pixels.count == width * height, width > 4, height > 4 else {
            throw EdgeDetectorError.invalidDimensions
        }
        // Fine scale: σ ≈ 1.0 (radius 2, default kernel)
        let fineEdges = try canny(
            pixels: pixels, width: width, height: height,
            lowThreshold: 0.05, highThreshold: 0.15
        )
        // Coarse scale: σ ≈ 2.0 (double blur, lower thresholds for broader edges)
        let coarseBlurred = gaussianBlur(
            pixels: gaussianBlur(pixels: pixels, width: width, height: height, radius: 2),
            width: width, height: height, radius: 2
        )
        let (gxC, gyC, magC) = sobelGradients(pixels: coarseBlurred, width: width, height: height)
        let suppC = nonMaxSuppression(gx: gxC, gy: gyC, magnitude: magC, width: width, height: height)
        let coarseEdges = hysteresis(magnitude: suppC, width: width, height: height, low: 0.03, high: 0.10)

        // Merge: take the max of both scales at each pixel
        var merged = [Float](repeating: 0, count: width * height)
        for i in 0..<merged.count {
            merged[i] = max(fineEdges[i], coarseEdges[i])
        }
        return merged
    }

    // MARK: — Gaussian blur

    private static func gaussianBlur(pixels: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        // 5-tap kernel: σ ≈ 1.0
        let kernel: [Float] = [0.0625, 0.25, 0.375, 0.25, 0.0625]
        let kLen = kernel.count
        let padded = pixels
        var rowBlurred = [Float](repeating: 0, count: width * height)
        // Horizontal pass
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for k in 0..<kLen {
                    let sx = x + k - kLen / 2
                    let clampedX = max(0, min(width - 1, sx))
                    sum += padded[y * width + clampedX] * kernel[k]
                }
                rowBlurred[y * width + x] = sum
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        // Vertical pass
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for k in 0..<kLen {
                    let sy = y + k - kLen / 2
                    let clampedY = max(0, min(height - 1, sy))
                    sum += rowBlurred[clampedY * width + x] * kernel[k]
                }
                result[y * width + x] = sum
            }
        }
        return result
    }

    // MARK: — Sobel gradients

    private static func sobelGradients(
        pixels: [Float],
        width: Int,
        height: Int
    ) -> (gx: [Float], gy: [Float], magnitude: [Float]) {
        let n = width * height
        var gx = [Float](repeating: 0, count: n)
        var gy = [Float](repeating: 0, count: n)
        var mag = [Float](repeating: 0, count: n)

        let sobelX: [Float] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
        let sobelY: [Float] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sx: Float = 0; var sy: Float = 0
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let px = pixels[(y + ky - 1) * width + (x + kx - 1)]
                        sx += px * sobelX[ky * 3 + kx]
                        sy += px * sobelY[ky * 3 + kx]
                    }
                }
                gx[y * width + x] = sx
                gy[y * width + x] = sy
                mag[y * width + x] = (sx * sx + sy * sy).squareRoot()
            }
        }

        // Normalise magnitude to [0, 1]
        var maxVal: Float = 0
        vDSP_maxv(mag, 1, &maxVal, vDSP_Length(n))
        if maxVal > 0 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(mag, 1, &scale, &mag, 1, vDSP_Length(n))
        }

        return (gx, gy, mag)
    }

    // MARK: — Non-maximum suppression

    private static func nonMaxSuppression(
        gx: [Float],
        gy: [Float],
        magnitude: [Float],
        width: Int,
        height: Int
    ) -> [Float] {
        var result = [Float](repeating: 0, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let mag = magnitude[i]
                guard mag > 0 else { continue }

                // Quantise gradient angle to 4 directions (0, 45, 90, 135 degrees)
                let angle = atan2(gy[i], gx[i]) * (180.0 / .pi)
                let absAngle = (angle + 180).truncatingRemainder(dividingBy: 180)

                var n1: Float = 0; var n2: Float = 0
                if absAngle < 22.5 || absAngle >= 157.5 {
                    n1 = magnitude[y * width + (x + 1)]
                    n2 = magnitude[y * width + (x - 1)]
                } else if absAngle < 67.5 {
                    n1 = magnitude[(y - 1) * width + (x + 1)]
                    n2 = magnitude[(y + 1) * width + (x - 1)]
                } else if absAngle < 112.5 {
                    n1 = magnitude[(y - 1) * width + x]
                    n2 = magnitude[(y + 1) * width + x]
                } else {
                    n1 = magnitude[(y - 1) * width + (x - 1)]
                    n2 = magnitude[(y + 1) * width + (x + 1)]
                }

                if mag >= n1 && mag >= n2 {
                    result[i] = mag
                }
            }
        }
        return result
    }

    // MARK: — Hysteresis thresholding

    private static func hysteresis(
        magnitude: [Float],
        width: Int,
        height: Int,
        low: Float,
        high: Float
    ) -> [Float] {
        let n = width * height
        var result = [Float](repeating: 0, count: n)
        var strong = [Bool](repeating: false, count: n)
        var weak   = [Bool](repeating: false, count: n)

        for i in 0..<n {
            if magnitude[i] >= high { strong[i] = true }
            else if magnitude[i] >= low { weak[i] = true }
        }

        // Flood-fill strong edges: accept weak pixels adjacent to strong
        var stack: [Int] = (0..<n).filter { strong[$0] }
        var visited = strong
        while !stack.isEmpty {
            let idx = stack.removeLast()
            result[idx] = 1.0
            let x = idx % width; let y = idx / width
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = x + dx; let ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let ni = ny * width + nx
                    if !visited[ni] && weak[ni] {
                        visited[ni] = true
                        stack.append(ni)
                    }
                }
            }
        }
        return result
    }
}
