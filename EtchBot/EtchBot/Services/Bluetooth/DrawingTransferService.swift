// DrawingTransferService.swift — EtchBot
// Manages chunked BLE transfer of encoded drawing data to the EtchBot device.
//
// Transfer protocol:
//   1. Send START_TRANSFER + total byte count.
//   2. Send encoded data in 244-byte chunks (MTU 247 - 3 ATT header).
//   3. Wait for Transfer Status notification (readyForNextChunk = true) between chunks.
//   4. Send END_TRANSFER.
//   5. Device verifies CRC and sends Device Status update.
//   6. App sends START_DRAWING.

import Foundation
import Combine

public enum TransferError: Error, LocalizedError {
    case noDeviceConnected
    case encodingFailed
    case deviceNotReady
    case transferTimeout
    case crcMismatch

    public var errorDescription: String? {
        switch self {
        case .noDeviceConnected: return "No EtchBot device connected."
        case .encodingFailed:    return "Failed to encode drawing path."
        case .deviceNotReady:    return "Device is not ready to receive data."
        case .transferTimeout:   return "Transfer timed out. Check Bluetooth connection."
        case .crcMismatch:       return "Data integrity error. Please retry."
        }
    }
}

/// Progress of an in-flight BLE transfer.
public struct TransferProgress: Sendable {
    public let bytesSent: Int
    public let totalBytes: Int
    public let chunksSent: Int
    public var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesSent) / Double(totalBytes)
    }
}

@MainActor
public final class DrawingTransferService: ObservableObject {

    @Published public var transferProgress: TransferProgress?
    @Published public var isTransferring: Bool = false
    @Published public var transferError: TransferError?

    private let chunkSize = 244  // bytes per BLE write (MTU 247 - 3 overhead)
    private let chunkTimeout: TimeInterval = 5.0

    // MARK: — Public API

    /// Encode and transfer a DrawingPath to the connected device, then start drawing.
    public func transferAndStart(path: DrawingPath, connection: BLEDeviceConnection) async throws {
        guard connection.isReady else { throw TransferError.deviceNotReady }

        // Encode path
        let encodedPath: DrawingPath
        do {
            encodedPath = try DrawingPathEncoder.encode(path)
        } catch {
            throw TransferError.encodingFailed
        }
        guard let data = encodedPath.encodedData else { throw TransferError.encodingFailed }

        isTransferring = true
        transferError = nil
        defer { isTransferring = false }

        let totalBytes = data.count

        // 1. START_TRANSFER
        connection.sendStartTransfer(totalBytes: UInt32(totalBytes))
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms for device to prepare

        // 2. Send chunks
        var offset = 0
        var chunksSent = 0

        while offset < totalBytes {
            let end = min(offset + chunkSize, totalBytes)
            let chunk = data[offset..<end]
            connection.writeDrawingChunk(Data(chunk))
            offset = end
            chunksSent += 1

            transferProgress = TransferProgress(
                bytesSent: offset,
                totalBytes: totalBytes,
                chunksSent: chunksSent
            )

            // Wait for ready signal (with timeout)
            let didReceiveReady = await waitForChunkAck(connection: connection)
            if !didReceiveReady { throw TransferError.transferTimeout }

            // Yield to keep UI responsive
            await Task.yield()
        }

        // 3. END_TRANSFER
        connection.sendCommand(.endTransfer)
        try await Task.sleep(nanoseconds: 300_000_000)  // 300ms for CRC check

        // 4. START_DRAWING
        connection.sendCommand(.startDrawing)
    }

    // MARK: — Private

    private func waitForChunkAck(connection: BLEDeviceConnection) async -> Bool {
        let deadline = Date().addingTimeInterval(chunkTimeout)
        while Date() < deadline {
            if connection.transferStatus?.readyForNextChunk == true { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms poll
        }
        return false
    }
}
