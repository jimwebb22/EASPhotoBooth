// EtchBotBLEProtocol.swift — EtchBot
// GATT service and characteristic UUIDs, and command/status enumerations
// for the EtchBot BLE protocol.

import Foundation
import CoreBluetooth

// MARK: — Service and Characteristic UUIDs

nonisolated public enum EtchBotUUID {
    /// Main EtchBot GATT service
    public static let service              = CBUUID(string: "EB010001-0001-1000-8000-00805F9B34FB")
    /// Device status (Read, Notify)
    public static let deviceStatus         = CBUUID(string: "EB010002-0001-1000-8000-00805F9B34FB")
    /// Drawing data (Write without response)
    public static let drawingData          = CBUUID(string: "EB010003-0001-1000-8000-00805F9B34FB")
    /// Transfer control (Write)
    public static let transferControl      = CBUUID(string: "EB010004-0001-1000-8000-00805F9B34FB")
    /// Calibration data (Read, Write)
    public static let calibrationData      = CBUUID(string: "EB010005-0001-1000-8000-00805F9B34FB")
    /// Transfer status (Read, Notify)
    public static let transferStatus       = CBUUID(string: "EB010006-0001-1000-8000-00805F9B34FB")
}

// MARK: — Transfer Control Commands

nonisolated public enum TransferCommand: UInt8 {
    case startTransfer  = 0x01  // Begin path upload; send with 4-byte total size appended
    case endTransfer    = 0x02  // Upload complete, verify CRC
    case startDrawing   = 0x10  // Begin autonomous drawing
    case pause          = 0x11  // Pause drawing, hold position
    case resume         = 0x12  // Resume from current position
    case cancel         = 0x13  // Stop drawing
    case home           = 0x20  // Execute homing routine
    case calibrateH     = 0x30  // Draw horizontal calibration line
    case calibrateV     = 0x31  // Draw vertical calibration line
    case calibrateBH    = 0x32  // Draw horizontal backlash test patterns
    case calibrateBV    = 0x33  // Draw vertical backlash test patterns
    case setSpeed       = 0x40  // Set motor speed (1-byte 0–255 follows)
}

// MARK: — Device Status

nonisolated public enum DeviceState: UInt8, Sendable {
    case idle        = 0
    case receiving   = 1
    case drawing     = 2
    case paused      = 3
    case complete    = 4
    case error       = 5
    case homing      = 6
    case calibrating = 7
}

/// Parsed device status notification (7 bytes on wire).
nonisolated public struct DeviceStatus: Sendable {
    public let state: DeviceState
    public let currentMoveIndex: UInt16
    public let totalMoves: UInt16
    public let errorCode: UInt8
    public let powerStatus: UInt8

    public var progressFraction: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(currentMoveIndex) / Double(totalMoves)
    }

    public init?(data: Data) {
        guard data.count >= 7 else { return nil }
        guard let state = DeviceState(rawValue: data[0]) else { return nil }
        self.state = state
        self.currentMoveIndex = UInt16(data[1]) | (UInt16(data[2]) << 8)
        self.totalMoves       = UInt16(data[3]) | (UInt16(data[4]) << 8)
        self.errorCode        = data[5]
        self.powerStatus      = data[6]
    }
}

/// Transfer status notification (4 bytes on wire).
nonisolated public struct TransferStatus: Sendable {
    public let chunksReceived: UInt8
    public let bytesReceived: UInt16
    public let readyForNextChunk: Bool

    public init?(data: Data) {
        guard data.count >= 4 else { return nil }
        self.chunksReceived   = data[0]
        self.bytesReceived    = UInt16(data[1]) | (UInt16(data[2]) << 8)
        self.readyForNextChunk = data[3] != 0
    }
}

// MARK: — Calibration Data Wire Format

nonisolated public extension CalibrationData {
    /// Encode calibration data to 12-byte wire format for BLE.
    func toWireFormat() -> Data {
        var data = Data(capacity: 12)
        // stepsPerMm as uint16 × 10 (1 decimal place precision)
        data.appendUInt16LE(UInt16(stepsPerMmHorizontal * 10))
        data.appendUInt16LE(UInt16(stepsPerMmVertical * 10))
        data.appendUInt16LE(UInt16(backlashHorizontalSteps))
        data.appendUInt16LE(UInt16(backlashVerticalSteps))
        data.appendUInt16LE(UInt16(drawingSpeedRPM))
        data.append(UInt8(homeOffsetX & 0xFF))
        data.append(UInt8(homeOffsetY & 0xFF))
        return data
    }

    /// Decode from wire format. Returns nil if data is too short.
    static func fromWireFormat(_ data: Data) -> CalibrationData? {
        guard data.count >= 12 else { return nil }
        let stepsH = Double(data.readUInt16LE(at: 0)) / 10.0
        let stepsV = Double(data.readUInt16LE(at: 2)) / 10.0
        let blH    = Int(data.readUInt16LE(at: 4))
        let blV    = Int(data.readUInt16LE(at: 6))
        let speed  = Int(data.readUInt16LE(at: 8))
        let offX   = Int(data[10])
        let offY   = Int(data[11])
        return CalibrationData(
            stepsPerMmHorizontal: stepsH,
            stepsPerMmVertical: stepsV,
            backlashHorizontalSteps: blH,
            backlashVerticalSteps: blV,
            homeOffsetX: offX,
            homeOffsetY: offY,
            drawingSpeedRPM: speed,
            isCalibrated: true
        )
    }
}

// MARK: — Data helpers (package-private)

nonisolated extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
}
