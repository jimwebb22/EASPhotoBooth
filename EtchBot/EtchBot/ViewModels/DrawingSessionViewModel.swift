// DrawingSessionViewModel.swift — EtchBot
// Monitors a live drawing session via BLE Device Status notifications.

import Foundation
import SwiftUI
import Combine

@MainActor
public final class DrawingSessionViewModel: ObservableObject {

    // MARK: — Published state
    @Published public var currentMove: Int = 0
    @Published public var totalMoves: Int = 0
    @Published public var isPaused: Bool = false
    @Published public var isComplete: Bool = false
    @Published public var isConnected: Bool = false

    public var progressFraction: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(currentMove) / Double(totalMoves)
    }

    public var estimatedSecondsRemaining: Int {
        guard totalMoves > 0, currentMove < totalMoves else { return 0 }
        let remainingMoves = totalMoves - currentMove
        let stepsPerSecond = 333
        return remainingMoves / stepsPerSecond
    }

    public var connectionStatusText: String {
        if isComplete { return "Drawing complete" }
        if !isConnected { return "Disconnected — drawing continues on device" }
        if isPaused { return "Paused" }
        return "Drawing…"
    }

    public var connectionColor: Color {
        if !isConnected { return .orange }
        if isComplete { return .green }
        return .green
    }

    // MARK: — Private
    private let bleManager: BLEManager
    private let transferService: DrawingTransferService
    private var cancellables = Set<AnyCancellable>()

    public init(bleManager: BLEManager, transferService: DrawingTransferService) {
        self.bleManager = bleManager
        self.transferService = transferService
        bindToDeviceStatus()
    }

    // MARK: — Binding

    private func bindToDeviceStatus() {
        bleManager.$connectedDevice
            .sink { [weak self] connection in
                self?.isConnected = connection != nil
                if let self, let connection {
                    connection.$deviceStatus
                        .compactMap { $0 }
                        .sink { [weak self] status in
                            self?.update(from: status)
                        }
                        .store(in: &self.cancellables)
                }
            }
            .store(in: &cancellables)
    }

    private func update(from status: DeviceStatus) {
        currentMove = Int(status.currentMoveIndex)
        totalMoves = Int(status.totalMoves)
        isPaused = status.state == .paused
        isComplete = status.state == .complete
        isConnected = true
    }

    // MARK: — Commands

    public func togglePause() {
        guard let conn = bleManager.connectedDevice else { return }
        if isPaused {
            conn.sendCommand(.resume)
        } else {
            conn.sendCommand(.pause)
        }
    }

    public func cancel() {
        bleManager.connectedDevice?.sendCommand(.cancel)
    }
}
