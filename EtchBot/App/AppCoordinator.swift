// AppCoordinator.swift — EtchBot
// Central coordinator: owns all top-level services and view models.
// Injected as environment objects throughout the app.

import SwiftUI
import Combine

@MainActor
public final class AppCoordinator: ObservableObject {

    // MARK: — Services
    let bleManager: BLEManager
    let deviceStore: DeviceStore
    let drawingHistoryStore: DrawingHistoryStore
    let transferService: DrawingTransferService

    // MARK: — ViewModels
    let deviceViewModel: DeviceViewModel
    let imageProcessingViewModel: ImageProcessingViewModel
    let drawingSessionViewModel: DrawingSessionViewModel
    let calibrationViewModel: CalibrationViewModel

    // MARK: — Navigation state
    @Published var activeSheet: AppSheet?

    public enum AppSheet: String, Identifiable {
        case camera, deviceList, drawingSession, calibration
        public var id: String { rawValue }
    }

    public init() {
        let bleManager = BLEManager()
        let deviceStore = DeviceStore()
        let drawingHistoryStore = DrawingHistoryStore()
        let transferService = DrawingTransferService()

        self.bleManager = bleManager
        self.deviceStore = deviceStore
        self.drawingHistoryStore = drawingHistoryStore
        self.transferService = transferService

        self.deviceViewModel = DeviceViewModel(bleManager: bleManager, deviceStore: deviceStore)
        self.imageProcessingViewModel = ImageProcessingViewModel()
        self.drawingSessionViewModel = DrawingSessionViewModel(bleManager: bleManager, transferService: transferService)
        self.calibrationViewModel = CalibrationViewModel(bleManager: bleManager, deviceStore: deviceStore)
    }

    // MARK: — Navigation helpers

    func openCamera() { activeSheet = .camera }
    func openDeviceList() { activeSheet = .deviceList }
    func openDrawingSession() { activeSheet = .drawingSession }
    func openCalibration() { activeSheet = .calibration }
    func closeSheet() { activeSheet = nil }
}
