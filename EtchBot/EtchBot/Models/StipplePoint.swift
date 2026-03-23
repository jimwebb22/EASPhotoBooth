// StipplePoint.swift — EtchBot
// A single point in the weighted Voronoi stippling output.

import Foundation

/// A stipple point in Etch-a-Sketch drawing-space coordinates.
/// Coordinates are in the working resolution (0...500 x, 0...320 y by default).
nonisolated public struct StipplePoint: Sendable, Equatable, Hashable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    /// Euclidean distance to another point.
    public func distance(to other: StipplePoint) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Distance squared (cheaper than distance when only comparing).
    public func distanceSquared(to other: StipplePoint) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
