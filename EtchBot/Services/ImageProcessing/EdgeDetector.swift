// EdgeDetector.swift — EtchBot
// Canny edge detection implemented via vDSP convolution.
//
// Simplified Canny pipeline:
//   1. Gaussian blur — vDSP_f5x5 (noise reduction)
//   2. Sobel gradients — vDSP_f3x3 ×2, magnitude via vDSP_vdist
//   3. Non-maximum suppression (thin edges to 1px)
//   4. Double-threshold hysteresis
//
// vDSP convolutions zero the outputs near the image border, which would
// read as a strong spurious gradient ring; magnitudes within 3 px of the
// border are therefore suppressed before normalization.

import Foundation
import Accelerate

public enum EdgeDetectorError: Error {
    case invalidDimensions
}

public final class EdgeDetector: Sendable {

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

    // MARK: — Downsampling

    /// 2×2 max-pool downsample (factor 2) for edge maps. Max pooling keeps
    /// thin 1-px edges that averaging would wash out below threshold.
    public static func downsampleMax2x(
        _ pixels: [Float],
        width: Int,
        height: Int
    ) -> (pixels: [Float], width: Int, height: Int) {
        let outW = width / 2
        let outH = height / 2
        var out = [Float](repeating: 0, count: outW * outH)
        for y in 0..<outH {
            for x in 0..<outW {
                let sx = x * 2
                let sy = y * 2
                var m = pixels[sy * width + sx]
                if sx + 1 < width { m = max(m, pixels[sy * width + sx + 1]) }
                if sy + 1 < height { m = max(m, pixels[(sy + 1) * width + sx]) }
                if sx + 1 < width, sy + 1 < height { m = max(m, pixels[(sy + 1) * width + sx + 1]) }
                out[y * outW + x] = m
            }
        }
        return (out, outW, outH)
    }

    // MARK: — Gaussian blur (vDSP)

    private static func gaussianBlur(pixels: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        // 5×5 Gaussian = outer product of the 5-tap binomial kernel
        // [1, 4, 6, 4, 1] / 16 (σ ≈ 1.0).
        let tap: [Float] = [1, 4, 6, 4, 1]
        var kernel = [Float](repeating: 0, count: 25)
        for i in 0..<5 {
            for j in 0..<5 {
                kernel[i * 5 + j] = tap[i] * tap[j] / 256.0
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        pixels.withUnsafeBufferPointer { src in
            vDSP_f5x5(src.baseAddress!, vDSP_Length(height), vDSP_Length(width), kernel, &result)
        }
        return result
    }

    // MARK: — Sobel gradients (vDSP)

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

        pixels.withUnsafeBufferPointer { src in
            vDSP_f3x3(src.baseAddress!, vDSP_Length(height), vDSP_Length(width), sobelX, &gx)
            vDSP_f3x3(src.baseAddress!, vDSP_Length(height), vDSP_Length(width), sobelY, &gy)
        }

        // magnitude = sqrt(gx² + gy²)
        vDSP_vdist(gx, 1, gy, 1, &mag, 1, vDSP_Length(n))

        // Suppress the convolution border: the blur/Sobel outputs are zeroed
        // near the edge of the buffer, which otherwise reads as a strong
        // gradient ring around the image.
        let margin = min(3, width / 2, height / 2)
        for y in 0..<height {
            for x in 0..<width {
                if x < margin || x >= width - margin || y < margin || y >= height - margin {
                    mag[y * width + x] = 0
                }
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
