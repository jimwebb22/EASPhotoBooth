// CalibrationViewModel.swift — EtchBot
// Drives the calibration wizard: sends BLE commands, saves results.

import Foundation
import Combine

@MainActor
public final class CalibrationViewModel: ObservableObject {

    @Published public var isHoming: Bool = false
    @Published public var homingComplete: Bool = false
    @Published public var isDrawingCalibration: Bool = false
    @Published public var calibrationLineDrawn: Bool = false
    @Published public var backlashPatternsDrawn: Bool = false

    /// Number of steps used for the calibration line (default: 4000 = 100mm at 40 steps/mm)
    public let calibrationLineSteps = 4000

    private let bleManager: BLEManager
    private let deviceStore: DeviceStore
    private var workingCalibration: CalibrationData = .defaults
    private var cancellables = Set<AnyCancellable>()
    private var connectedDeviceID: String?

    public init(bleManager: BLEManager, deviceStore: DeviceStore) {
        self.bleManager = bleManager
        self.deviceStore = deviceStore
        bleManager.$connectedDevice
            .sink { [weak self] conn in
                self?.connectedDeviceID = conn?.peripheral.identifier.uuidString
                if let conn {
                    // Load existing calibration for this device
                    if let profile = deviceStore.loadAll().first(where: {
                        $0.id == conn.peripheral.identifier.uuidString
                    }) {
                        self?.workingCalibration = profile.calibration
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: — Commands

    public func sendHomeCommand() {
        isHoming = true
        bleManager.connectedDevice?.sendCommand(.home)
        // Simulate completion after a delay (real implementation would read device status)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isHoming = false
            self?.homingComplete = true
        }
    }

    public func drawCalibrationLine(axis: CalibrationAxis) {
        isDrawingCalibration = true
        calibrationLineDrawn = false
        let command: TransferCommand = axis == .horizontal ? .calibrateH : .calibrateV
        bleManager.connectedDevice?.sendCommand(command)
        // Simulate completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.isDrawingCalibration = false
            self?.calibrationLineDrawn = true
        }
    }

    public func drawBacklashPatterns(axis: CalibrationAxis) {
        isDrawingCalibration = true
        backlashPatternsDrawn = false
        let command: TransferCommand = axis == .horizontal ? .calibrateBH : .calibrateBV
        bleManager.connectedDevice?.sendCommand(command)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.isDrawingCalibration = false
            self?.backlashPatternsDrawn = true
        }
    }

    // MARK: — Save calibration values

    public func saveStepsPerMm(axis: CalibrationAxis, measuredMM: Double) {
        let stepsPerMm = Double(calibrationLineSteps) / measuredMM
        if axis == .horizontal {
            workingCalibration.stepsPerMmHorizontal = stepsPerMm
        } else {
            workingCalibration.stepsPerMmVertical = stepsPerMm
        }
        persistCalibration()
    }

    public func saveBacklash(axis: CalibrationAxis, steps: Int) {
        if axis == .horizontal {
            workingCalibration.backlashHorizontalSteps = steps
        } else {
            workingCalibration.backlashVerticalSteps = steps
        }
        workingCalibration.isCalibrated = true
        persistCalibration()
        // Push calibration to device
        bleManager.connectedDevice?.writeCalibration(workingCalibration)
    }

    private func persistCalibration() {
        guard let id = connectedDeviceID else { return }
        var devices = deviceStore.loadAll()
        if let idx = devices.firstIndex(where: { $0.id == id }) {
            devices[idx].calibration = workingCalibration
            deviceStore.save(devices[idx])
        }
    }
}
