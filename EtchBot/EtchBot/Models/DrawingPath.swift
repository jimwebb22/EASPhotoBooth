// DrawingPath.swift — EtchBot
// The complete, ready-to-execute drawing path.

import Foundation

/// A direction in 8-compass encoding used for motor step commands.
nonisolated public enum StepDirection: UInt8, CaseIterable, Sendable {
    case east      = 0  // +X
    case northeast = 1  // +X, +Y
    case north     = 2  // +Y
    case northwest = 3  // -X, +Y
    case west      = 4  // -X
    case southwest = 5  // -X, -Y
    case south     = 6  // -Y
    case southeast = 7  // +X, -Y

    /// X delta for this direction (-1, 0, +1).
    public var dx: Int { Self.dxTable[Int(rawValue)] }
    /// Y delta for this direction (-1, 0, +1).
    public var dy: Int { Self.dyTable[Int(rawValue)] }

    private static let dxTable: [Int] = [1, 1, 0, -1, -1, -1,  0,  1]
    private static let dyTable: [Int] = [0, 1, 1,  1,  0, -1, -1, -1]
}

/// A single move command: move `runLength` steps in `direction`.
nonisolated public struct MoveCommand: Sendable, Equatable {
    public let direction: StepDirection
    public let runLength: Int   // 1…8191

    public init(direction: StepDirection, runLength: Int) {
        precondition(runLength >= 1 && runLength <= 8191)
        self.direction = direction
        self.runLength = runLength
    }
}

/// The complete, optimized drawing path ready for BLE transmission and execution.
nonisolated public struct DrawingPath: Sendable {
    /// Ordered sequence of move commands constituting the drawing.
    public let moves: [MoveCommand]
    /// Total horizontal steps in drawing-space.
    public let widthInSteps: Int
    /// Total vertical steps in drawing-space.
    public let heightInSteps: Int
    /// Estimated draw time in seconds based on assumed motor speed.
    public let estimatedDrawTimeSeconds: Int
    /// The encoded binary representation (populated by DrawingPathEncoder).
    public var encodedData: Data?

    public init(
        moves: [MoveCommand],
        widthInSteps: Int,
        heightInSteps: Int,
        estimatedDrawTimeSeconds: Int,
        encodedData: Data? = nil
    ) {
        self.moves = moves
        self.widthInSteps = widthInSteps
        self.heightInSteps = heightInSteps
        self.estimatedDrawTimeSeconds = estimatedDrawTimeSeconds
        self.encodedData = encodedData
    }

    /// Human-readable estimated draw time string.
    public var estimatedDrawTimeString: String {
        let minutes = estimatedDrawTimeSeconds / 60
        let seconds = estimatedDrawTimeSeconds % 60
        if minutes == 0 {
            return "~\(seconds)s"
        } else if seconds == 0 {
            return "~\(minutes) min"
        } else {
            return "~\(minutes) min \(seconds)s"
        }
    }
}
