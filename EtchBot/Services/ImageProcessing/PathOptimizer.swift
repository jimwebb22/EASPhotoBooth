// PathOptimizer.swift — EtchBot
// Converts the TSP tour into motor-ready move commands.
//
// Steps:
//   1. Scale stipple coordinates → physical motor steps (using CalibrationData)
//   2. Decompose each point-to-point segment into Bresenham line steps
//   3. Run-length encode consecutive steps in the same direction
//   4. Return an array of MoveCommand ready for DrawingPathEncoder
//
// Backlash compensation is owned entirely by the firmware (MotorController
// injects slack take-up steps on axis reversal, using the values pushed via
// the BLE calibration write). The encoded path is purely geometric —
// compensating here as well would double-compensate every reversal.

import Foundation

public final class PathOptimizer: Sendable {

    // MARK: — Public entry point

    /// Convert an ordered TSP tour into a DrawingPath.
    ///
    /// - Parameters:
    ///   - tour: Ordered point indices (e.g. from TSPSolver.breakTourAtLongestEdge),
    ///     or the identity order when `points` is already an ordered polyline.
    ///   - points: Stipple points in density-map coordinates.
    ///   - densityMapSize: (width, height) of the working resolution.
    ///   - calibration: Device calibration data.
    /// - Returns: DrawingPath with encoded motor commands.
    public static func optimize(
        tour: [Int],
        points: [StipplePoint],
        densityMapWidth: Int,
        densityMapHeight: Int,
        calibration: CalibrationData
    ) -> DrawingPath {
        guard tour.count >= 2 else {
            return DrawingPath(moves: [], widthInSteps: 0, heightInSteps: 0, estimatedDrawTimeSeconds: 0)
        }

        let stepsW = calibration.drawingAreaWidthSteps
        let stepsH = calibration.drawingAreaHeightSteps
        let scaleX = Double(stepsW) / Double(densityMapWidth)
        let scaleY = Double(stepsH) / Double(densityMapHeight)

        // Convert stipple points to integer motor step coordinates
        let stepCoords: [(x: Int, y: Int)] = tour.map { idx in
            let p = points[idx]
            return (
                x: Int((Double(p.x) * scaleX).rounded()),
                y: Int((Double(p.y) * scaleY).rounded())
            )
        }

        // Build raw step sequence via Bresenham decomposition
        var moves: [MoveCommand] = []
        moves.reserveCapacity(tour.count * 10)

        var currentX = stepCoords[0].x
        var currentY = stepCoords[0].y

        for i in 1..<stepCoords.count {
            let target = stepCoords[i]
            guard target.x != currentX || target.y != currentY else { continue }

            let bresenhamSteps = bresenham(fromX: currentX, fromY: currentY, toX: target.x, toY: target.y)
            for step in bresenhamSteps {
                appendMove(direction: step, steps: 1, into: &moves)
            }

            currentX = target.x
            currentY = target.y
        }

        // Merge consecutive same-direction commands into run-length commands
        let merged = mergeRunLengths(moves: moves)

        // Estimate draw time from the actual encoded steps at the configured
        // motor speed (200 steps/rev, matching the firmware). Diagonal runs
        // step both motors sequentially, so they cost ~2× a single-axis step.
        let weightedSteps = merged.reduce(0) { sum, move in
            let diagonal = move.direction.dx != 0 && move.direction.dy != 0
            return sum + move.runLength * (diagonal ? 2 : 1)
        }
        let stepsPerSecond = max(1.0, Double(calibration.drawingSpeedRPM) * 200.0 / 60.0)
        let estimatedSeconds = max(1, Int((Double(weightedSteps) / stepsPerSecond).rounded()))

        return DrawingPath(
            moves: merged,
            widthInSteps: stepsW,
            heightInSteps: stepsH,
            estimatedDrawTimeSeconds: estimatedSeconds
        )
    }

    // MARK: — Bresenham line decomposition

    /// Returns the 8-direction steps needed to travel from (x0,y0) to (x1,y1).
    private static func bresenham(fromX x0: Int, fromY y0: Int, toX x1: Int, toY y1: Int) -> [StepDirection] {
        var steps: [StepDirection] = []
        var x = x0; var y = y0
        let dx = abs(x1 - x); let dy = abs(y1 - y)
        let sx = x1 > x ? 1 : (x1 < x ? -1 : 0)
        let sy = y1 > y ? 1 : (y1 < y ? -1 : 0)
        var err = dx - dy

        while x != x1 || y != y1 {
            let e2 = 2 * err
            var moveX = 0; var moveY = 0
            if e2 > -dy { err -= dy; moveX = sx }
            if e2 < dx  { err += dx; moveY = sy }
            if let dir = direction(dx: moveX, dy: moveY) {
                steps.append(dir)
            }
            x += moveX; y += moveY
        }
        return steps
    }

    private static func direction(dx: Int, dy: Int) -> StepDirection? {
        switch (dx, dy) {
        case (1,  0): return .east
        case (1,  1): return .northeast
        case (0,  1): return .north
        case (-1, 1): return .northwest
        case (-1, 0): return .west
        case (-1,-1): return .southwest
        case (0, -1): return .south
        case (1, -1): return .southeast
        default: return nil
        }
    }

    // MARK: — Helpers

    private static func appendMove(direction: StepDirection, steps: Int, into moves: inout [MoveCommand]) {
        guard steps > 0 else { return }
        var remaining = steps
        while remaining > 0 {
            let chunk = min(remaining, 8191)
            moves.append(MoveCommand(direction: direction, runLength: chunk))
            remaining -= chunk
        }
    }

    private static func mergeRunLengths(moves: [MoveCommand]) -> [MoveCommand] {
        guard !moves.isEmpty else { return [] }
        var result: [MoveCommand] = []
        result.reserveCapacity(moves.count / 4)
        var current = moves[0]
        for i in 1..<moves.count {
            let m = moves[i]
            if m.direction == current.direction && current.runLength + m.runLength <= 8191 {
                current = MoveCommand(direction: current.direction, runLength: current.runLength + m.runLength)
            } else {
                result.append(current)
                current = m
            }
        }
        result.append(current)
        return result
    }
}
