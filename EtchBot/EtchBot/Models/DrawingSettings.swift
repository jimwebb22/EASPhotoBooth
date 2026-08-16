// DrawingSettings.swift — EtchBot
// User-adjustable settings controlling the image-to-drawing pipeline.

import Foundation

/// All user-controllable parameters for a drawing conversion session.
nonisolated public struct DrawingSettings: Codable, Sendable, Equatable {
    // MARK: — Stippling density
    /// Number of stipple points (Voronoi seeds). Controls "opacity"/detail.
    /// Range: 500…6000. Default: 2500.
    public var pointCount: Int

    // MARK: — Image preprocessing
    /// Contrast boost multiplier applied before stippling. Range: 0.5…2.0.
    public var contrastMultiplier: Double

    /// Whether to blend edge-detected contours into the density map.
    /// When true: 30% edges + 70% tonal grayscale. When false: 100% tonal.
    public var edgeEmphasisEnabled: Bool

    /// Blend weight for edges (0.0 = no edges, 1.0 = edges only).
    /// Only effective when edgeEmphasisEnabled is true.
    public var edgeWeight: Double

    // MARK: — Algorithm tuning (advanced, not user-facing by default)
    /// Iterations for Lloyd's relaxation. Default: 40.
    public var voronoiIterations: Int

    /// How many random starting tours to try for TSP nearest-neighbor phase. Default: 8.
    public var tspStartingPositions: Int

    // MARK: — Presets
    /// Quick preset: fast but low detail, suitable for testing.
    public static let quick = DrawingSettings(
        pointCount: 3000,
        contrastMultiplier: 1.2,
        edgeEmphasisEnabled: true,
        edgeWeight: 0.4,
        voronoiIterations: 30,
        tspStartingPositions: 5
    )

    /// Balanced preset: good photo resemblance with reasonable draw time.
    public static let balanced = DrawingSettings(
        pointCount: 8000,
        contrastMultiplier: 1.5,
        edgeEmphasisEnabled: true,
        edgeWeight: 0.5,
        voronoiIterations: 50,
        tspStartingPositions: 8
    )

    /// Detailed preset: highest quality, longer draw and compute time.
    public static let detailed = DrawingSettings(
        pointCount: 15000,
        contrastMultiplier: 1.5,
        edgeEmphasisEnabled: true,
        edgeWeight: 0.5,
        voronoiIterations: 60,
        tspStartingPositions: 10
    )

    // MARK: — Defaults
    public static let defaults = DrawingSettings.balanced

    // MARK: — Slider bounds (used by UI)
    public static let pointCountRange: ClosedRange<Int> = 500...20000
    public static let contrastRange: ClosedRange<Double> = 0.5...3.0

    public init(
        pointCount: Int = 8000,
        contrastMultiplier: Double = 1.5,
        edgeEmphasisEnabled: Bool = true,
        edgeWeight: Double = 0.5,
        voronoiIterations: Int = 50,
        tspStartingPositions: Int = 8
    ) {
        self.pointCount = pointCount
        self.contrastMultiplier = contrastMultiplier
        self.edgeEmphasisEnabled = edgeEmphasisEnabled
        self.edgeWeight = edgeWeight
        self.voronoiIterations = voronoiIterations
        self.tspStartingPositions = tspStartingPositions
    }

    /// Estimated draw time in minutes with variable speed motor control.
    /// At higher point counts, average speed increases due to longer segments at 150-200 RPM.
    /// Heuristic: ~0.5 seconds per stipple point (accounting for variable speed).
    public var estimatedDrawTimeMinutes: Int {
        let seconds = Double(pointCount) * 0.5
        return max(1, Int(seconds / 60.0))
    }
}
