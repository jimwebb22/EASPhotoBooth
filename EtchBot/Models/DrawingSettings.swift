// DrawingSettings.swift — EtchBot
// User-adjustable settings controlling the image-to-drawing pipeline.

import Foundation

/// All user-controllable parameters for a drawing conversion session.
public struct DrawingSettings: Codable, Sendable, Equatable {

    // MARK: — Render style

    /// How the image is converted into a single continuous line.
    public enum RenderStyle: String, Codable, Sendable, CaseIterable {
        /// Contours traced from the image are drawn as line segments and
        /// stippling fills in the tone — best likeness for portraits.
        case hybrid
        /// Classic TSP art: pure stipple tour (tone only, softer edges).
        case stipple
    }

    /// Rendering pipeline. Default: .hybrid (contour + stipple).
    public var renderStyle: RenderStyle

    // MARK: — Stippling density
    /// Number of stipple points (Voronoi seeds). Controls "opacity"/detail.
    /// Range: 500…6000. Default: 2500.
    public var pointCount: Int

    // MARK: — Image preprocessing
    /// Contrast boost multiplier applied before stippling. Range: 0.5…2.0.
    public var contrastMultiplier: Double

    /// Whether to blend edge-detected contours into the density map
    /// (stipple style only — the hybrid style draws contours explicitly).
    public var edgeEmphasisEnabled: Bool

    /// Blend weight for edges (0.0 = no edges, 1.0 = edges only).
    /// Only effective when edgeEmphasisEnabled is true and style is .stipple.
    public var edgeWeight: Double

    // MARK: — Algorithm tuning (advanced, not user-facing by default)
    /// Iterations for Lloyd's relaxation. Default: 40.
    public var voronoiIterations: Int

    /// How many random starting tours to try for TSP nearest-neighbor phase. Default: 8.
    public var tspStartingPositions: Int

    // MARK: — Defaults
    public static let defaults = DrawingSettings(
        renderStyle: .hybrid,
        pointCount: 2500,
        contrastMultiplier: 1.0,
        edgeEmphasisEnabled: true,
        edgeWeight: 0.35,
        voronoiIterations: 40,
        tspStartingPositions: 8
    )

    // MARK: — Slider bounds (used by UI)
    public static let pointCountRange: ClosedRange<Int> = 500...6000
    public static let contrastRange: ClosedRange<Double> = 0.5...2.0
    public static let edgeWeightRange: ClosedRange<Double> = 0.0...0.8

    public init(
        renderStyle: RenderStyle = .hybrid,
        pointCount: Int = 2500,
        contrastMultiplier: Double = 1.0,
        edgeEmphasisEnabled: Bool = true,
        edgeWeight: Double = 0.35,
        voronoiIterations: Int = 40,
        tspStartingPositions: Int = 8
    ) {
        self.renderStyle = renderStyle
        self.pointCount = pointCount
        self.contrastMultiplier = contrastMultiplier
        self.edgeEmphasisEnabled = edgeEmphasisEnabled
        self.edgeWeight = edgeWeight
        self.voronoiIterations = voronoiIterations
        self.tspStartingPositions = tspStartingPositions
    }

    /// Estimated draw time in minutes for a given point count at 100 RPM motor speed.
    /// Rough heuristic: ~0.8 seconds per stipple point at 100 RPM.
    public var estimatedDrawTimeMinutes: Int {
        let seconds = Double(pointCount) * 0.8
        return max(1, Int(seconds / 60.0))
    }
}
