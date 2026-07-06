// Extensions.swift — EtchBot
// Utility extensions on standard and framework types.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: — Float / Double math helpers

public extension Float {
    /// Clamp to [lo, hi].
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

public extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

// MARK: — Seeded RNG

/// SplitMix64 — a small, fast, seedable RNG. Used by the tour solvers so
/// tests can reproduce results exactly. Not for cryptographic use.
public struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: — Working canvas

/// The working-resolution canvas the pipeline operates in.
/// Its aspect ratio MUST match the physical drawing area (175mm × 120mm,
/// see CalibrationData) — PathOptimizer maps canvas pixels to motor steps
/// with independent X/Y scales, so any mismatch stretches the drawing.
/// 500 × 343 ≈ 175:120. Platform-independent so SPM tests can reference it.
public enum WorkingCanvas {
    public static let width = 500
    public static let height = 343  // round(500 * 120 / 175)
}

// MARK: — 2D density map helpers

/// A flat 2D array of Float values, row-major (row * width + col).
public struct DensityMap: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [Float]  // 0.0 = white/transparent; 1.0 = black/max density

    public init(width: Int, height: Int, pixels: [Float]) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Value at pixel (x, y), clamped to bounds.
    public func value(x: Int, y: Int) -> Float {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return pixels[y * width + x]
    }

    /// Mean density across the map (0 = fully blank, 1 = fully dark).
    /// Used to auto-tune the stipple point count per image.
    public var meanDensity: Double {
        guard !pixels.isEmpty else { return 0 }
        var total: Double = 0
        for v in pixels { total += Double(v) }
        return total / Double(pixels.count)
    }

    /// Bilinear interpolation for sub-pixel (fx, fy) in [0, width) x [0, height).
    public func interpolate(fx: Float, fy: Float) -> Float {
        let x0 = Int(fx)
        let y0 = Int(fy)
        let x1 = Swift.min(x0 + 1, width - 1)
        let y1 = Swift.min(y0 + 1, height - 1)
        let tx = fx - Float(x0)
        let ty = fy - Float(y0)
        let v00 = value(x: x0, y: y0)
        let v10 = value(x: x1, y: y0)
        let v01 = value(x: x0, y: y1)
        let v11 = value(x: x1, y: y1)
        return (1 - tx) * (1 - ty) * v00
             + tx       * (1 - ty) * v10
             + (1 - tx) * ty       * v01
             + tx       * ty       * v11
    }
}

// MARK: — StipplePoint ↔ CGPoint (available on Apple platforms)

#if canImport(CoreGraphics)
public extension StipplePoint {
    init(_ point: CGPoint) {
        self.init(x: Float(point.x), y: Float(point.y))
    }
    var cgPoint: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
#endif

// MARK: — CRC-16/IBM (used for BLE transfer verification)

public extension Data {
    /// Compute CRC-16/IBM (poly 0x8005, init 0x0000, reflect in/out).
    var crc16: UInt16 {
        var crc: UInt16 = 0x0000
        for byte in self {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return crc
    }
}

// MARK: — Array helpers

public extension Array {
    /// Safely access element at index, returning nil if out of bounds.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
