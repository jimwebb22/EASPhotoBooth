# EtchBot: iOS-Controlled Etch-a-Sketch Drawing Robot

## Complete Project Implementation Brief

**Version:** 1.0
**Date:** March 12, 2026
**Project Manager:** Jim
**Implementation Tool:** Claude Code

---

# Part I: Project Overview

## Vision

EtchBot is a complete system that transforms photographs into continuous-line drawings on a real Etch-a-Sketch. The user captures or selects a photo on their iPhone, adjusts drawing density, previews the result, and sends it wirelessly to a motorized Etch-a-Sketch that draws the image autonomously. The iOS app is themed to look like an Etch-a-Sketch, and the entire system is designed for App Store publication.

## System Architecture Summary

The system has three major components:

1. **iOS Application (Swift/SwiftUI):** Camera capture, image processing pipeline, TSP-art algorithm, drawing preview, BLE communication, calibration interface.
2. **Firmware (Arduino/C++ on Adafruit Feather nRF52840):** BLE GATT server, drawing path storage (in RAM), dual stepper motor control with backlash compensation, homing routine, progress reporting.
3. **Hardware Assembly:** Adafruit Feather nRF52840 Express, DC Motor + Stepper FeatherWing, two stepper motors with belt drives to Etch-a-Sketch knobs, 12V power supply.

## Algorithm Pipeline (TSP Art)

The image-to-drawing conversion follows a proven computer art technique called TSP Art, pioneered by mathematician Robert Bosch. The pipeline produces long, smooth, continuous lines — far superior to nearest-neighbor pixel hopping. The steps are:

1. **Preprocessing:** Convert photo to grayscale. Apply adaptive contrast enhancement. Optionally apply edge detection to emphasize contours.
2. **Weighted Voronoi Stippling (Secord's Algorithm):** Distribute N dots across the image where dot density is proportional to image darkness. Darker regions get more dots. The number N is controlled by the user's "density" slider. Iterate Lloyd's relaxation with density-weighted centroids until dots reach stable positions.
3. **TSP Solving:** Feed the dot positions to a Traveling Salesman Problem heuristic solver (2-opt with nearest-neighbor initialization). This finds the shortest single continuous path visiting every dot. The result is inherently a single unbroken line — exactly what the Etch-a-Sketch requires.
4. **Path Optimization:** Smooth the path for mechanical execution. Scale coordinates to the Etch-a-Sketch drawing area. Apply backlash compensation offsets. Convert to stepper motor step sequences.

The user's "density" control adjusts N (the number of stipple points): fewer points = lighter/faster drawing; more points = darker/slower drawing. This is the "opacity" control.

---

# Part II: Project Phases

## Phase 1 — iOS Application (Start Immediately, Remote with Claude Code)

This is the primary software deliverable and can be developed entirely on a Mac without any hardware present. The app will include a simulator mode that previews drawings without requiring a connected Etch-a-Sketch.

## Phase 2 — Hardware Assembly & Firmware (When Hands-On Time Available)

Physical assembly of the motor rig and Feather-based controller, plus firmware development for BLE communication and motor control.

## Phase 3 — Integration, Calibration & App Store Submission

Connect the app to real hardware, tune backlash compensation, build the calibration interface, and prepare for App Store review.

---

# Part III: Phase 1 — iOS Application (Claude Code Implementation Plan)

## Project Setup

### Xcode Project Configuration

- **Project Name:** EtchBot
- **Bundle Identifier:** com.[yourdomain].etchbot
- **Minimum Deployment Target:** iOS 17.0
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Architecture:** MVVM with Coordinator pattern
- **Dependencies:** None external. All image processing and TSP solving is implemented natively in Swift using Accelerate framework for performance.

### Directory Structure

```
EtchBot/
├── EtchBot.xcodeproj
├── EtchBot/
│   ├── App/
│   │   ├── EtchBotApp.swift
│   │   └── AppCoordinator.swift
│   ├── Models/
│   │   ├── DrawingPath.swift
│   │   ├── StipplePoint.swift
│   │   ├── DeviceProfile.swift
│   │   ├── DrawingSettings.swift
│   │   └── CalibrationData.swift
│   ├── Views/
│   │   ├── Main/
│   │   │   ├── HomeView.swift
│   │   │   └── EtchASketchFrame.swift
│   │   ├── Camera/
│   │   │   ├── CameraView.swift
│   │   │   ├── CameraPreviewLayer.swift
│   │   │   └── PhotoLibraryPicker.swift
│   │   ├── Editor/
│   │   │   ├── ImageEditorView.swift
│   │   │   ├── DensitySliderView.swift
│   │   │   ├── DrawingPreviewView.swift
│   │   │   └── ProcessingProgressView.swift
│   │   ├── Drawing/
│   │   │   ├── DrawingSessionView.swift
│   │   │   ├── DrawingProgressBar.swift
│   │   │   └── DrawingCompleteView.swift
│   │   ├── Devices/
│   │   │   ├── DeviceListView.swift
│   │   │   ├── DevicePairingView.swift
│   │   │   └── DeviceDetailView.swift
│   │   └── Calibration/
│   │       ├── CalibrationWizardView.swift
│   │       ├── BacklashCalibrationView.swift
│   │       └── StepsCalibrationView.swift
│   ├── ViewModels/
│   │   ├── CameraViewModel.swift
│   │   ├── ImageProcessingViewModel.swift
│   │   ├── DrawingSessionViewModel.swift
│   │   ├── DeviceViewModel.swift
│   │   └── CalibrationViewModel.swift
│   ├── Services/
│   │   ├── ImageProcessing/
│   │   │   ├── ImagePreprocessor.swift
│   │   │   ├── EdgeDetector.swift
│   │   │   ├── VoronoiStippler.swift
│   │   │   ├── TSPSolver.swift
│   │   │   ├── PathOptimizer.swift
│   │   │   └── DrawingPathEncoder.swift
│   │   ├── Bluetooth/
│   │   │   ├── BLEManager.swift
│   │   │   ├── BLEDeviceConnection.swift
│   │   │   ├── EtchBotBLEProtocol.swift
│   │   │   └── DrawingTransferService.swift
│   │   └── Persistence/
│   │       ├── DeviceStore.swift
│   │       └── DrawingHistoryStore.swift
│   ├── Utilities/
│   │   ├── VoronoiDiagram.swift
│   │   ├── KDTree.swift
│   │   └── Extensions.swift
│   └── Resources/
│       └── Assets.xcassets/
├── EtchBotTests/
│   ├── ImageProcessingTests/
│   ├── BluetoothTests/
│   ├── ViewModelTests/
│   └── AppStoreComplianceTests/
└── EtchBotUITests/
```

## Module Specifications

### Module 1: Image Preprocessing (`ImagePreprocessor.swift`)
- Convert UIImage to grayscale using Accelerate vImage
- Apply CLAHE for contrast enhancement
- Resize to 500x320 working resolution
- Output normalized density map (2D Float array, 0.0=white, 1.0=black)
- Optional edge detection overlay (30% edges, 70% tone)
- **Performance Target:** Under 200ms on iPhone 12+

### Module 2: Weighted Voronoi Stippling (`VoronoiStippler.swift`)
- Input: density map + target point count N (500–6000)
- Initial placement via rejection sampling
- Lloyd's relaxation with density-weighted centroids (30–50 iterations)
- Fortune's sweep-line algorithm for Voronoi diagram
- **Performance Target:** Under 3 seconds for 3000 points

### Module 3: TSP Solver (`TSPSolver.swift`)
- Phase 1: Nearest-neighbor with KD-tree (5–10 random starts)
- Phase 2: 2-opt improvement
- Phase 3: Or-opt refinement (optional)
- Progress reporting via Combine publisher
- **Performance Target:** Under 5 seconds for 3000 points

### Module 4: Path Optimizer (`PathOptimizer.swift`)
- Coordinate scaling to physical Etch-a-Sketch steps
- Path breaking near home corner
- Backlash compensation injection on direction reversals
- Bresenham diagonal decomposition
- Output: compact binary path representation

### Module 5: Drawing Path Encoder (`DrawingPathEncoder.swift`)
- 12-byte header with magic bytes, dimensions, CRC-16
- 2-byte move commands (3-bit direction + 13-bit run length)
- Direction encoding: 0=East, 1=NE, 2=North, 3=NW, 4=West, 5=SW, 6=South, 7=SE

### Module 6: BLE Communication
- EtchBot Service UUID: EB010001-0001-1000-8000-00805F9B34FB
- 5 characteristics: Device Status, Drawing Data, Transfer Control, Calibration Data, Transfer Status
- Chunked transfer with CRC verification
- Background BLE support (bluetooth-central mode)

### Module 7–11: UI Modules
- Etch-a-Sketch themed frame (red #D4262A, grey screen #C8C8C8)
- Camera integration (AVCaptureSession)
- Image editor with density/contrast sliders
- Drawing session monitor with live path animation
- Calibration wizard

---

# Part IV: Phase 2 — Hardware & Firmware

See full brief for parts list and firmware specification.

**Core Hardware:**
- Adafruit Feather nRF52840 Express (#4062)
- DC Motor + Stepper FeatherWing (#2927)
- 2x NEMA 17 steppers
- GT2 belt drive to Etch-a-Sketch knobs
- 12V 2A power supply

**Firmware:** Arduino/C++, BLE GATT server, 50KB RAM path buffer, MICROSTEP motor mode

---

# Part V: Phase 3 — Integration & App Store

See full brief for integration checklist and App Store submission checklist.

---

# Appendix A: Etch-a-Sketch Physical Specifications

| Property | Classic/Full Size |
|----------|------------------|
| Drawing area | ~175mm x 120mm |
| Drawing resolution | ~550 x 370 lines |
| Knob shaft diameter | ~6mm (D-shaft) |
| Backlash (typical) | 1–2mm per axis |

# Appendix B: BLE Protocol Quick Reference

| Command | Value | Description |
|---------|-------|-------------|
| START_TRANSFER | 0x01 | Begin path upload |
| END_TRANSFER | 0x02 | Upload complete, verify CRC |
| START_DRAWING | 0x10 | Begin autonomous drawing |
| PAUSE | 0x11 | Pause drawing |
| RESUME | 0x12 | Resume drawing |
| CANCEL | 0x13 | Stop drawing |
| HOME | 0x20 | Execute homing routine |
| CALIBRATE_H | 0x30 | Horizontal calibration |
| CALIBRATE_V | 0x31 | Vertical calibration |
| CALIBRATE_BH | 0x32 | Horizontal backlash test |
| CALIBRATE_BV | 0x33 | Vertical backlash test |
| SET_SPEED | 0x40 | Set motor speed |

# Appendix C: Algorithm Parameter Defaults

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| Stipple point count | 2500 | 500–6000 | Primary opacity control |
| Voronoi iterations | 40 | — | Convergence-based early stop |
| TSP starting positions | 8 | — | More = better tour |
| 2-opt max iterations | 50 | — | Early stop on no improvement |
| Edge detection weight | 0.3 | 0–1 | 30% edges, 70% tone |
| Contrast multiplier | 1.0 | 0.5–2.0 | Pre-processing |
| Steps per mm (H/V) | 40 | Via calibration | Hardware dependent |
| Backlash H/V | 60 steps | Via calibration | ~1.5mm at 40 steps/mm |
| Drawing speed | 100 RPM | 20–200 RPM | BLE adjustable |
