# EtchBot — Product Manager Action Items

**Owner:** Jim
**Created:** 2026-03-13
**Status:** Phase 1 iOS app complete — awaiting desk tasks before Xcode integration

---

## Immediate Next Steps (Phase 1 Closeout)

These tasks must be completed before the iOS app can be built and run in Xcode.

### 1. Create Xcode Project

- [ ] Open Xcode → File → New → Project → iOS App
  - Product Name: `EtchBot`
  - Interface: SwiftUI
  - Language: Swift
  - Minimum Deployment Target: iOS 17.0
- [ ] Drag all source files from `EtchBot/` directory into the Xcode project navigator
- [ ] Add required frameworks in Build Phases → Link Binary With Libraries:
  - `Accelerate.framework`
  - `CoreBluetooth.framework`
  - `AVFoundation.framework`
  - `PhotosUI.framework`
  - `CoreImage.framework`
- [ ] In Signing & Capabilities → add **Background Modes** → check **Uses Bluetooth LE accessories**
- [ ] Replace the auto-generated `Info.plist` entries with contents from `EtchBot/Resources/Info.plist`

### 2. Set Your Bundle Identifier

- [ ] Replace the placeholder `com.etchbot.app` with your Apple Developer domain (e.g. `com.yourname.etchbot`) in:
  - Xcode project settings → Signing & Capabilities → Bundle Identifier
  - `EtchBot/Resources/Info.plist` → `CFBundleIdentifier`

### 3. Apple Developer Account Setup

- [ ] Confirm your Apple Developer Program membership is active at [developer.apple.com](https://developer.apple.com)
- [ ] Create an App ID for the EtchBot bundle identifier in the Developer Portal
- [ ] Create/confirm a provisioning profile (Development for now; Distribution later for App Store)
- [ ] Confirm signing certificate is installed in Keychain

### 4. Custom Font Decision

- [ ] Decide on the Etch-a-Sketch frame header font:
  - **Option A (default):** System rounded font — already implemented, no action needed
  - **Option B:** License and bundle a Futura-style font (e.g. Nunito Heavy from Google Fonts — free) — requires adding `.ttf` to Assets and `UIAppFonts` entry in Info.plist
- [ ] Inform Claude Code of decision if Option B selected

### 5. Test Photos

- [ ] Prepare 2–3 test photos with varying complexity for pipeline testing:
  - Simple object on plain background (e.g. a mug)
  - Portrait / face
  - Detailed scene (e.g. cityscape)
- [ ] Save to iPhone camera roll for use with the app once installed on device

### 6. Privacy Policy & Support Page

- [ ] Create a GitHub Pages site (or use any host) with:
  - **Privacy Policy** stating: no data collection, all processing on-device, no analytics
  - **Support page** with contact email or GitHub Issues link
- [ ] Note both URLs — needed for App Store Connect before submission

---

## When You Have the Hardware (Phase 2) — Firmware Ready ✓

**The firmware is complete in `etchbot-firmware/`.** Steps to flash and test:

### 7. Flash the Firmware

- [ ] Install Arduino IDE 2.x from [arduino.cc](https://www.arduino.cc/en/software)
- [ ] Add Adafruit board package URL in IDE Preferences:
  `https://adafruit.github.io/arduino-board-index/package_adafruit_index.json`
- [ ] Install board: Tools → Boards Manager → "Adafruit nRF52" → Install
- [ ] Install libraries via Tools → Manage Libraries:
  - **Adafruit Motor Shield V2 Library**
  - **Adafruit BusIO** (may auto-install as dependency)
- [ ] Open `etchbot-firmware/etchbot-firmware.ino`
- [ ] Select board: Tools → Board → **Adafruit Feather nRF52840 Express**
- [ ] Connect Feather via USB, select port, click Upload

### 8. Hardware Assembly

- [ ] Order parts from Adafruit if not already on hand (~$55–$115, see `Docs/PROJECT_BRIEF.md` Part IV)
- [ ] Assess existing stepper motors:
  - Verify bi-polar (4 wires)
  - Identify coil pairs with a multimeter
  - Confirm current draw < 1.2A per coil
- [ ] Assess existing belt/pulley setup:
  - Verify GT2 6mm belt and pulley tooth count
- [ ] Solder stacking headers onto Feather nRF52840
- [ ] Solder terminal blocks onto Stepper FeatherWing
- [ ] Stack FeatherWing onto Feather
- [ ] Wire stepper motors: **M1+M2 = horizontal axis (X), M3+M4 = vertical axis (Y)**
- [ ] Connect 12V power supply to FeatherWing VMotor terminal

### 9. Initial Firmware Test (before mounting to Etch-a-Sketch)

- [ ] Power on Feather — 3 LED blinks = ready
- [ ] Open nRF Connect app on iPhone
- [ ] Scan for "EtchBot" device and connect
- [ ] Verify all 5 characteristics appear in the GATT explorer
- [ ] Write `0x20` (HOME command) to the Transfer Control characteristic
  - Motors should spin slowly for a few seconds, then stop
- [ ] Write `0x30` (CALIBRATE_H) — motor X should step 4000 steps east
- [ ] If motors don't move: check I2C wiring, power supply voltage, and coil wire connections
- [ ] If wrong motor moves: swap motor port assignments in `config.h`

### 10. Mount and Calibrate

- [ ] Mount motors and belts to Etch-a-Sketch
- [ ] Run **Calibration Wizard** from the iOS app (Devices → select device → Run Calibration Wizard)
- [ ] Verify drawings with simple test shapes before a full photo drawing

---

## Pre-App Store Submission (Phase 3)

- [ ] Design app icon (Etch-a-Sketch themed, 1024×1024px minimum)
- [ ] Capture App Store screenshots on real device (iPhone 15 Pro, iPhone 15 Pro Max, iPhone SE required sizes)
- [ ] Write App Store description and keywords
- [ ] Complete App Store Connect listing:
  - App category: Utilities or Photography
  - Age rating: 4+
  - Privacy nutrition label: "Data Not Collected" for all categories
  - Privacy policy URL (from step 6 above)
  - Support URL
- [ ] App Review notes to include: *"This app connects via Bluetooth to a custom Etch-a-Sketch drawing robot. The image processing and preview features work without hardware. A demo mode is available from the home screen."*
- [ ] Answer export compliance: **No** (no proprietary encryption beyond system BLE)
- [ ] Submit for review

---

## Open Questions Requiring Your Input

| # | Question | Default Used | Action |
|---|----------|-------------|--------|
| 1 | Bundle ID domain | `com.etchbot.app` | Replace with your Apple Developer domain |
| 2 | Custom font | System rounded | Decide Option A or B (see step 4 above) |
| 3 | Privacy policy URL | (placeholder) | Host page and provide URL |
| 4 | Motor spec confirmation | NEMA 17, 40 steps/mm | Verify against your hardware before calibration |
| 5 | App Store developer name | (unset) | Confirm name to appear on App Store listing |

---

## Reference Links

- **Build plan & progress tracker:** `Docs/BUILD_PLAN.md`
- **Full project specification:** `Docs/PROJECT_BRIEF.md`
- **Branch:** `claude/init-etchbot-ios-app-wtlxM`
- **Adafruit Feather nRF52840 Express:** [Product #4062](https://www.adafruit.com/product/4062)
- **DC Motor + Stepper FeatherWing:** [Product #2927](https://www.adafruit.com/product/2927)
