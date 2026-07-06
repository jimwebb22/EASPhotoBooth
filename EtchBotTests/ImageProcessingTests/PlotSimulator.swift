// PlotSimulator.swift — EtchBotTests
// Replays an encoded MoveCommand sequence through a physical model of the
// Etch-a-Sketch mechanism, producing the pen trajectory in step space.
//
// The lash model: each axis engages the pen through a gear gap of `lash`
// steps. After the axis reverses direction, the first `lash` motor steps
// cross the gap (taking up slack) without moving the pen. lash = 0 models
// an ideal mechanism.
//
// This is the shared verification harness (WS0) — quality workstreams
// assert their improvements against trajectories and metrics from here.

import Foundation
@testable import EtchBotCore

struct PlotSimulator {

    struct Trajectory {
        /// Pen position after every motor step, starting with the initial (0, 0).
        let penPositions: [(x: Int, y: Int)]
        /// Total motor steps executed (compensation + drawing).
        let motorSteps: Int

        var finalPen: (x: Int, y: Int) { penPositions.last ?? (0, 0) }

        /// Bounds of the pen trajectory.
        var penBounds: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
            var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
            for p in penPositions {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            return (minX, maxX, minY, maxY)
        }

        /// Total distance the pen (not the motor) travels, in Chebyshev steps.
        var penTravel: Int {
            guard penPositions.count > 1 else { return 0 }
            var total = 0
            for i in 1..<penPositions.count {
                let dx = abs(penPositions[i].x - penPositions[i - 1].x)
                let dy = abs(penPositions[i].y - penPositions[i - 1].y)
                total += max(dx, dy)
            }
            return total
        }

        /// Number of direction reversals of the pen on each axis.
        /// An out-and-back excursion adds two reversals where the ideal
        /// trajectory has one (or none) — the fingerprint of compensation
        /// steps leaking into the geometric path.
        var axisReversalCounts: (x: Int, y: Int) {
            var lastDX = 0, lastDY = 0
            var revX = 0, revY = 0
            for i in 1..<penPositions.count {
                let dx = penPositions[i].x - penPositions[i - 1].x
                let dy = penPositions[i].y - penPositions[i - 1].y
                if dx != 0 {
                    let s = dx > 0 ? 1 : -1
                    if lastDX != 0 && s != lastDX { revX += 1 }
                    lastDX = s
                }
                if dy != 0 {
                    let s = dy > 0 ? 1 : -1
                    if lastDY != 0 && s != lastDY { revY += 1 }
                    lastDY = s
                }
            }
            return (revX, revY)
        }
    }

    /// One axis with gear lash. `engagement` is the motor's position within
    /// the gap, 0...lash; the pen only moves when the motor is pressed
    /// against the corresponding edge of the gap. Starts engaged forward.
    private struct LashAxis {
        let lash: Int
        var pen = 0
        var engagement: Int

        init(lash: Int) {
            self.lash = lash
            self.engagement = lash
        }

        mutating func step(_ sign: Int) {
            if sign > 0 {
                if engagement < lash { engagement += 1 } else { pen += 1 }
            } else if sign < 0 {
                if engagement > 0 { engagement -= 1 } else { pen -= 1 }
            }
        }
    }

    /// Replay `moves` and return the pen trajectory.
    static func run(moves: [MoveCommand], lashX: Int = 0, lashY: Int = 0) -> Trajectory {
        var ax = LashAxis(lash: lashX)
        var ay = LashAxis(lash: lashY)
        var positions: [(x: Int, y: Int)] = []
        positions.reserveCapacity(moves.reduce(1) { $0 + $1.runLength })
        positions.append((0, 0))
        var motorSteps = 0

        for move in moves {
            let dx = move.direction.dx
            let dy = move.direction.dy
            for _ in 0..<move.runLength {
                if dx != 0 { ax.step(dx) }
                if dy != 0 { ay.step(dy) }
                motorSteps += 1
                positions.append((ax.pen, ay.pen))
            }
        }

        return Trajectory(penPositions: positions, motorSteps: motorSteps)
    }
}

// MARK: — Synthetic density-map fixtures

enum DensityFixtures {

    /// Small canvas with the same aspect ratio as the working canvas.
    static let width = 120
    static let height = 82

    /// Mostly-blank canvas with one dark disc — exercises background handling.
    /// A quality pipeline places (nearly) all stipple points inside the disc.
    static func blankWithDisc() -> DensityMap {
        var pixels = [Float](repeating: 0, count: width * height)
        let cx = Float(width) * 0.7
        let cy = Float(height) * 0.35
        let r = Float(height) * 0.2
        for y in 0..<height {
            for x in 0..<width {
                let dx = Float(x) - cx
                let dy = Float(y) - cy
                if (dx * dx + dy * dy).squareRoot() < r {
                    pixels[y * width + x] = 1.0
                }
            }
        }
        return DensityMap(width: width, height: height, pixels: pixels)
    }

    /// Horizontal tone ramp — exercises tonal distribution.
    static func gradientRamp() -> DensityMap {
        var pixels = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * width + x] = Float(x) / Float(width - 1)
            }
        }
        return DensityMap(width: width, height: height, pixels: pixels)
    }

    /// High-contrast silhouette (dark rectangle on white) — sharp edges.
    static func silhouette() -> DensityMap {
        var pixels = [Float](repeating: 0, count: width * height)
        for y in (height / 4)..<(3 * height / 4) {
            for x in (width / 3)..<(2 * width / 3) {
                pixels[y * width + x] = 0.9
            }
        }
        return DensityMap(width: width, height: height, pixels: pixels)
    }
}
