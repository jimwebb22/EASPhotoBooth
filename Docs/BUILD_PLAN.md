# EtchBot Build Plan & Progress Tracker

**Last Updated:** 2026-03-13 — Phase 1 (iOS) ✓ | Phase 2 (Firmware) ✓
**Branch:** `claude/init-etchbot-ios-app-wtlxM`

This document is the authoritative progress reference. After each session (including after rate-limit pauses), consult this file to determine where to resume.

---

## How to Resume After Rate Limit

1. `git pull origin claude/init-etchbot-ios-app-wtlxM`
2. Read this file (`Docs/BUILD_PLAN.md`) for current status
3. Find the first step marked `[ ]` (incomplete) and resume from there
4. Refer to `Docs/PROJECT_BRIEF.md` for full specifications

---

## Build Steps

### Phase 1A — Foundation

- [x] **Step 1: Store project brief + create build plan**
  - `Docs/PROJECT_BRIEF.md` — full project brief
  - `Docs/BUILD_PLAN.md` — this file
  - _Completed: 2026-03-12_

- [x] **Step 2: Project directory structure + Package.swift**
  - All source directories created
  - `Package.swift` for SPM compatibility and testing
  - `EtchBot/Resources/Info.plist` with all required keys
  - _Completed: 2026-03-12_

- [x] **Step 3: Data models**
  - `EtchBot/Models/DrawingPath.swift`
  - `EtchBot/Models/StipplePoint.swift`
  - `EtchBot/Models/DeviceProfile.swift`
  - `EtchBot/Models/DrawingSettings.swift`
  - `EtchBot/Models/CalibrationData.swift`
  - _Completed: 2026-03-12_

### Phase 1B — Image Processing Pipeline

- [x] **Step 4: Utilities (KDTree + Extensions)**
  - `EtchBot/Utilities/KDTree.swift` — spatial indexing for NN search
  - `EtchBot/Utilities/Extensions.swift` — CGPoint, UIImage helpers
  - _Completed: 2026-03-12_

- [x] **Step 5: Image Preprocessor + Edge Detector**
  - `EtchBot/Services/ImageProcessing/ImagePreprocessor.swift`
  - `EtchBot/Services/ImageProcessing/EdgeDetector.swift`
  - Grayscale, CLAHE, resize to 500x320, density map output
  - _Completed: 2026-03-12_

- [x] **Step 6: Voronoi Diagram + Voronoi Stippler**
  - `EtchBot/Utilities/VoronoiDiagram.swift` — Fortune's sweep-line
  - `EtchBot/Services/ImageProcessing/VoronoiStippler.swift` — Secord's algorithm
  - Rejection sampling init, Lloyd's relaxation, density-weighted centroids
  - _Completed: 2026-03-12_

- [x] **Step 7: TSP Solver**
  - `EtchBot/Services/ImageProcessing/TSPSolver.swift`
  - Nearest-neighbor with KD-tree, 2-opt improvement, Or-opt refinement
  - Progress reporting via AsyncStream
  - _Completed: 2026-03-12_

- [x] **Step 8: Path Optimizer + Drawing Path Encoder**
  - `EtchBot/Services/ImageProcessing/PathOptimizer.swift`
  - `EtchBot/Services/ImageProcessing/DrawingPathEncoder.swift`
  - Backlash compensation, Bresenham decomposition, binary encoding
  - _Completed: 2026-03-12_

### Phase 1C — BLE Communication

- [x] **Step 9: BLE Protocol + Manager**
  - `EtchBot/Services/Bluetooth/EtchBotBLEProtocol.swift`
  - `EtchBot/Services/Bluetooth/BLEManager.swift`
  - `EtchBot/Services/Bluetooth/BLEDeviceConnection.swift`
  - `EtchBot/Services/Bluetooth/DrawingTransferService.swift`
  - _Completed: 2026-03-12_

### Phase 1D — UI Layer

- [x] **Step 10: App entry point + AppCoordinator**
  - `EtchBot/App/EtchBotApp.swift`
  - `EtchBot/App/AppCoordinator.swift`
  - _Completed: 2026-03-12_

- [x] **Step 11: Core UI components (EtchASketchFrame + HomeView)**
  - `EtchBot/Views/Main/EtchASketchFrame.swift`
  - `EtchBot/Views/Main/HomeView.swift`
  - _Completed: 2026-03-12_

- [x] **Step 12: Camera views**
  - `EtchBot/Views/Camera/CameraView.swift`
  - `EtchBot/Views/Camera/CameraPreviewLayer.swift`
  - `EtchBot/Views/Camera/PhotoLibraryPicker.swift`
  - _Completed: 2026-03-12_

- [x] **Step 13: Editor views**
  - `EtchBot/Views/Editor/ImageEditorView.swift`
  - `EtchBot/Views/Editor/DensitySliderView.swift`
  - `EtchBot/Views/Editor/DrawingPreviewView.swift`
  - `EtchBot/Views/Editor/ProcessingProgressView.swift`
  - _Completed: 2026-03-12_

- [x] **Step 14: Drawing session + Devices + Calibration views**
  - `EtchBot/Views/Drawing/DrawingSessionView.swift`
  - `EtchBot/Views/Drawing/DrawingProgressBar.swift`
  - `EtchBot/Views/Drawing/DrawingCompleteView.swift`
  - `EtchBot/Views/Devices/DeviceListView.swift`
  - `EtchBot/Views/Devices/DevicePairingView.swift`
  - `EtchBot/Views/Devices/DeviceDetailView.swift`
  - `EtchBot/Views/Calibration/CalibrationWizardView.swift`
  - `EtchBot/Views/Calibration/BacklashCalibrationView.swift`
  - `EtchBot/Views/Calibration/StepsCalibrationView.swift`
  - _Completed: 2026-03-12_

### Phase 1E — ViewModels + Persistence

- [x] **Step 15: ViewModels**
  - `EtchBot/ViewModels/CameraViewModel.swift`
  - `EtchBot/ViewModels/ImageProcessingViewModel.swift`
  - `EtchBot/ViewModels/DrawingSessionViewModel.swift`
  - `EtchBot/ViewModels/DeviceViewModel.swift`
  - `EtchBot/ViewModels/CalibrationViewModel.swift`
  - _Completed: 2026-03-12_

- [x] **Step 16: Persistence services**
  - `EtchBot/Services/Persistence/DeviceStore.swift`
  - `EtchBot/Services/Persistence/DrawingHistoryStore.swift`
  - _Completed: 2026-03-12_

### Phase 1F — Tests

- [x] **Step 17: Unit tests — image processing**
  - `EtchBotTests/ImageProcessingTests/ImagePreprocessorTests.swift`
  - `EtchBotTests/ImageProcessingTests/VoronoiStipplerTests.swift`
  - `EtchBotTests/ImageProcessingTests/TSPSolverTests.swift`
  - `EtchBotTests/ImageProcessingTests/PathOptimizerTests.swift`
  - _Completed: 2026-03-12_

- [x] **Step 18: Unit tests — BLE + ViewModels**
  - `EtchBotTests/BluetoothTests/BLEProtocolTests.swift`
  - `EtchBotTests/BluetoothTests/DrawingTransferTests.swift`
  - `EtchBotTests/ViewModelTests/ImageProcessingViewModelTests.swift`
  - _Completed: 2026-03-12_

- [x] **Step 19: App Store compliance tests + UI tests**
  - `EtchBotTests/AppStoreComplianceTests/PrivacyComplianceTests.swift`
  - `EtchBotTests/AppStoreComplianceTests/UIComplianceTests.swift`
  - `EtchBotUITests/CameraFlowUITests.swift`
  - `EtchBotUITests/DrawingFlowUITests.swift`
  - `EtchBotUITests/CalibrationFlowUITests.swift`
  - _Completed: 2026-03-12_

---

## Phase 2 — Arduino Firmware

### Phase 2A — Firmware (Arduino/C++ for Adafruit Feather nRF52840)

- [x] **Step F1: config.h — constants and defaults**
  - `etchbot-firmware/config.h`
  - Motor ports, step mode, speed limits, buffer size, calibration defaults
  - _Completed: 2026-03-13_

- [x] **Step F2: path_storage — 50KB RAM buffer with CRC-16 verification**
  - `etchbot-firmware/path_storage.h/.cpp`
  - Chunked receive, magic-byte check, CRC-16/IBM matching iOS encoder
  - _Completed: 2026-03-13_

- [x] **Step F3: motor_controller — stepper abstraction**
  - `etchbot-firmware/motor_controller.h/.cpp`
  - Adafruit Motor Shield V2 wrapper, backlash compensation, position tracking
  - Diagonal moves via interleaved X+Y steps
  - _Completed: 2026-03-13_

- [x] **Step F4: ble_service — GATT service and callbacks**
  - `etchbot-firmware/ble_service.h/.cpp`
  - All 5 characteristics (Status, DrawData, Control, Calibration, TransferStatus)
  - Volatile command flags set by BLE callbacks, consumed by main loop
  - BLE advertising, connection/disconnection callbacks
  - _Completed: 2026-03-13_

- [x] **Step F5: drawing_executor — path decoding and motor driving**
  - `etchbot-firmware/drawing_executor.h/.cpp`
  - Cooperative tick() — processes N moves per loop to keep BLE responsive
  - Decodes 2-byte move commands (3-bit direction + 13-bit run length)
  - Pause/Resume/Cancel, progress BLE notifications
  - _Completed: 2026-03-13_

- [x] **Step F6: homing — overshoot homing routine**
  - `etchbot-firmware/homing.h/.cpp`
  - Drives both axes 110% of max travel toward corner stop (no limit switch needed)
  - Interleaved Bresenham movement for simultaneous X+Y homing
  - _Completed: 2026-03-13_

- [x] **Step F7: calibration — reference lines and backlash test patterns**
  - `etchbot-firmware/calibration.h/.cpp`
  - Horizontal and vertical reference lines (4000 steps, matches iOS wizard)
  - 5 backlash test patterns per axis (0, 30, 60, 90, 120 steps)
  - _Completed: 2026-03-13_

- [x] **Step F8: etchbot-firmware.ino — setup, loop, state machine**
  - `etchbot-firmware/etchbot-firmware.ino`
  - LittleFS persistent calibration storage
  - Full state machine: IDLE → RECEIVING → DRAWING → COMPLETE
  - Handles all BLE commands, auto-saves calibration on write
  - _Completed: 2026-03-13_

---

## Arduino IDE Setup (Jim's Task)

1. Install Arduino IDE 2.x from [arduino.cc](https://www.arduino.cc/en/software)
2. Add Adafruit nRF52 board package:
   - File → Preferences → Additional Boards Manager URLs:
     `https://adafruit.github.io/arduino-board-index/package_adafruit_index.json`
   - Tools → Board → Boards Manager → search "Adafruit nRF52" → Install
3. Select board: Tools → Board → "Adafruit Feather nRF52840 Express"
4. Install libraries via Library Manager (Tools → Manage Libraries):
   - "Adafruit Motor Shield V2 Library"
   - "Adafruit BusIO" (dependency, may auto-install)
5. Open `etchbot-firmware/etchbot-firmware.ino`
6. Connect Feather nRF52840 via USB
7. Select correct port: Tools → Port → (your Feather's COM/tty port)
8. Upload (→ button) — first upload takes ~30 seconds

---

## Xcode Project Setup (Jim's Task)

The Swift source files are all created. To open in Xcode:

1. Create new Xcode project: File → New → Project → iOS App
   - Product Name: `EtchBot`
   - Bundle ID: `com.[yourdomain].etchbot`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 17.0

2. Add all source files from `EtchBot/` directory to the Xcode project

3. Add these frameworks in Build Phases → Link Binary With Libraries:
   - `Accelerate.framework`
   - `CoreBluetooth.framework`
   - `AVFoundation.framework`
   - `PhotosUI.framework`
   - `CoreImage.framework`

4. Add background mode in Signing & Capabilities:
   - Background Modes → Uses Bluetooth LE accessories

5. Replace generated Info.plist entries with contents from `EtchBot/Resources/Info.plist`

---

## Questions for Jim (No Blockers — Development Proceeded with Defaults)

1. **Bundle ID domain:** Used `com.etchbot.app` as placeholder. Replace with your Apple Developer domain.
2. **Custom font:** Used system font (Futura-style via `.system(.largeTitle, design: .rounded)`). Confirm or provide a custom font file.
3. **Privacy policy URL:** Placeholder used in App Store metadata notes. Host at GitHub Pages and update before submission.
4. **Stepper motor specs:** Defaulted to NEMA 17, 200 steps/rev, 40 steps/mm. Verify against your hardware before calibration.

---

## Known Limitations / Phase 2 Dependencies

- `CameraView.swift` and `CameraPreviewLayer.swift` use `AVFoundation` — requires a real device (not simulator) for camera.
- BLE stack requires physical hardware for integration testing.
- Calibration wizard is functional in the app but requires connected hardware for actual calibration.
- Photo library picker uses `PHPickerViewController` — works in simulator.

---

## File Count Summary

| Area | Files |
|------|-------|
| App entry | 2 |
| Models | 5 |
| Views | 19 |
| ViewModels | 5 |
| Services | 10 |
| Utilities | 3 |
| Tests | 11 |
| **Firmware** | **8** |
| Docs | 2 |
| **Total** | **57** |
