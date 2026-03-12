// PathOptimizer.swift — EtchBot
// Converts the TSP tour into motor-ready move commands.
//
// Steps:
//   1. Scale stipple coordinates → physical motor steps (using CalibrationData)
//   2. Inject backlash compensation moves on direction reversals
//   3. Decompose each point-to-point segment into Bresenham line steps
//   4. Run-length encode consecutive steps in the same direction
//   5. Return an array of MoveCommand ready for DrawingPathEncoder

import Foundation

public final class PathOptimizer: Sendable {

    // MARK: — Public entry point

    /// Convert an ordered TSP tour into a DrawingPath.
    ///
    /// - Parameters:
    ///   - tour: Ordered point indices from TSPSolver.breakTourNearHome.
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
        var stepCoords: [(x: Int, y: Int)] = tour.map { idx in
            let p = points[idx]
            return (
                x: Int((Double(p.x) * scaleX).rounded()),
                y: Int((Double(p.y) * scaleY).rounded())
            )
        }

        // Build raw step sequence via Bresenham with backlash injection
        var moves: [MoveCommand] = []
        moves.reserveCapacity(tour.count * 10)

        var currentX = stepCoords[0].x
        var currentY = stepCoords[0].y
        var lastDX = 0  // last horizontal direction: -1, 0, +1
        var lastDY = 0  // last vertical direction

        for i in 1..<stepCoords.count {
            let target = stepCoords[i]
            let dx = target.x - currentX
            let dy = target.y - currentY
            guard dx != 0 || dy != 0 else { continue }

            // Determine axis directions for this segment
            let signX = dx == 0 ? 0 : (dx > 0 ? 1 : -1)
            let signY = dy == 0 ? 0 : (dy > 0 ? 1 : -1)

            // Backlash compensation: inject steps on direction reversal
            if lastDX != 0 && signX != 0 && signX != lastDX {
                let backlash = calibration.backlashHorizontalSteps
                let dir: StepDirection = signX > 0 ? .east : .west
                appendMove(direction: dir, steps: backlash, into: &moves)
                currentX += signX * backlash
            }
            if lastDY != 0 && signY != 0 && signY != lastDY {
                let backlash = calibration.backlashVerticalSteps
                let dir: StepDirection = signY > 0 ? .north : .south
                appendMove(direction: dir, steps: backlash, into: &moves)
                currentY += signY * backlash
            }

            // Bresenham decomposition
            let bresenhamSteps = bresenham(fromX: currentX, fromY: currentY, toX: target.x, toY: target.y)
            for step in bresenhamSteps {
                appendMove(direction: step, steps: 1, into: &moves)
            }

            lastDX = signX
            lastDY = signY
            currentX = target.x
            currentY = target.y
        }

        // Merge consecutive same-direction commands into run-length commands
        let merged = mergeRunLengths(moves: moves)

        // Estimate draw time: assume 100 RPM, 200 steps/rev → 333 steps/sec
        let totalSteps = merged.reduce(0) { $0 + $1.runLength }
        let stepsPerSecond = 333
        let estimatedSeconds = max(1, totalSteps / stepsPerSecond)

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
