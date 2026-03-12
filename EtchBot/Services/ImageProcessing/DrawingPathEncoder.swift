// DrawingPathEncoder.swift — EtchBot
// Encodes a DrawingPath into the compact binary format used for BLE transfer.
//
// Binary Protocol:
//   Header (12 bytes):
//     [0-1]  Magic:         0xEB 0x01
//     [2-3]  Move count:    uint16 LE
//     [4-5]  Width steps:   uint16 LE
//     [6-7]  Height steps:  uint16 LE
//     [8-9]  Est. seconds:  uint16 LE
//     [10-11] CRC-16:       uint16 LE (over payload only)
//   Payload (variable):
//     Each move = 2 bytes:
//       Byte 0: [7:5] direction (3 bits) | [4:0] run-length high 5 bits
//       Byte 1: run-length low 8 bits
//     Run-length = 13-bit value (0–8191), encoded big-endian across the two bytes
//       actual encoding: high5 = (runLen >> 8) & 0x1F; low8 = runLen & 0xFF

import Foundation

public enum DrawingPathEncoderError: Error {
    case tooManyMoves(Int)       // > 65535
    case emptyPath
}

public final class DrawingPathEncoder: Sendable {

    private static let magic0: UInt8 = 0xEB
    private static let magic1: UInt8 = 0x01

    // MARK: — Encode

    /// Encode a DrawingPath into Data.
    /// - Parameter path: The drawing path with move commands.
    /// - Returns: DrawingPath with encodedData populated.
    public static func encode(_ path: DrawingPath) throws -> DrawingPath {
        guard !path.moves.isEmpty else { throw DrawingPathEncoderError.emptyPath }
        guard path.moves.count <= 65535 else { throw DrawingPathEncoderError.tooManyMoves(path.moves.count) }

        // Build payload
        var payload = Data(capacity: path.moves.count * 2)
        for move in path.moves {
            let runLen = min(move.runLength, 8191)
            let high5 = UInt8((runLen >> 8) & 0x1F)
            let low8  = UInt8(runLen & 0xFF)
            let byte0 = (move.direction.rawValue << 5) | high5
            payload.append(byte0)
            payload.append(low8)
        }

        let crc = payload.crc16

        // Build header
        var header = Data(capacity: 12)
        header.append(magic0)
        header.append(magic1)
        header.appendUInt16LE(UInt16(path.moves.count))
        header.appendUInt16LE(UInt16(path.widthInSteps))
        header.appendUInt16LE(UInt16(path.heightInSteps))
        header.appendUInt16LE(UInt16(min(path.estimatedDrawTimeSeconds, 65535)))
        header.appendUInt16LE(crc)

        var encoded = header
        encoded.append(payload)

        return DrawingPath(
            moves: path.moves,
            widthInSteps: path.widthInSteps,
            heightInSteps: path.heightInSteps,
            estimatedDrawTimeSeconds: path.estimatedDrawTimeSeconds,
            encodedData: encoded
        )
    }

    // MARK: — Decode (for verification / testing)

    public struct DecodedHeader {
        public let moveCount: Int
        public let widthSteps: Int
        public let heightSteps: Int
        public let estimatedSeconds: Int
        public let payloadCRC: UInt16
    }

    /// Verify and decode a binary blob. Returns nil if magic bytes or CRC do not match.
    public static func verify(_ data: Data) -> DecodedHeader? {
        guard data.count >= 12 else { return nil }
        guard data[0] == magic0, data[1] == magic1 else { return nil }
        let moveCount = Int(data.readUInt16LE(at: 2))
        let widthSteps = Int(data.readUInt16LE(at: 4))
        let heightSteps = Int(data.readUInt16LE(at: 6))
        let estSecs = Int(data.readUInt16LE(at: 8))
        let storedCRC = data.readUInt16LE(at: 10)
        let payload = data.dropFirst(12)
        let computedCRC = Data(payload).crc16
        guard computedCRC == storedCRC else { return nil }
        return DecodedHeader(
            moveCount: moveCount,
            widthSteps: widthSteps,
            heightSteps: heightSteps,
            estimatedSeconds: estSecs,
            payloadCRC: storedCRC
        )
    }
}

// MARK: — Data helpers

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    func readUInt16LE(at offset: Int) -> UInt16 {
        let lo = UInt16(self[offset])
        let hi = UInt16(self[offset + 1])
        return lo | (hi << 8)
    }
}
