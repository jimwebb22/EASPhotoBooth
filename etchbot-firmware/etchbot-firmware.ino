// etchbot-firmware.ino — EtchBot Firmware
// Main entry point for the Adafruit Feather nRF52840 Express.
//
// Hardware: Adafruit Feather nRF52840 Express + DC Motor + Stepper FeatherWing
//
// Board package (Arduino IDE / Board Manager):
//   Name:    "Adafruit nRF52 Boards"
//   URL:     https://adafruit.github.io/arduino-board-index/package_adafruit_index.json
//   Version: 1.5.0 or later
//   Board:   "Adafruit Feather nRF52840 Express"
//
// Required libraries (install via Arduino Library Manager):
//   - Adafruit Motor Shield V2 Library  (by Adafruit)
//   - Adafruit BusIO                    (dependency, by Adafruit)
//   - Adafruit LittleFS                 (bundled with nRF52 BSP)
//
// The Bluefruit BLE stack is bundled with the Adafruit nRF52 BSP — no separate install.

#include <bluefruit.h>
#include <Adafruit_LittleFS.h>
#include <InternalFileSystem.h>

#include "config.h"
#include "path_storage.h"
#include "motor_controller.h"
#include "ble_service.h"
#include "drawing_executor.h"
#include "homing.h"
#include "calibration.h"

using namespace Adafruit_LittleFS_Namespace;

// ─────────────────────────────────────────────────────────────────────────────
// Persistent calibration storage
// ─────────────────────────────────────────────────────────────────────────────

// Stored in LittleFS (nRF52840 internal flash, separate from program flash).
struct StoredCalibration {
    uint16_t magic;
    float    stepsPerMmH;
    float    stepsPerMmV;
    uint16_t backlashH;
    uint16_t backlashV;
    uint8_t  speedRPM;
    uint16_t maxStepsH;
    uint16_t maxStepsV;
};

static StoredCalibration g_cal;   // active calibration values (RAM copy)

static void loadCalibration() {
    InternalFS.begin();
    File f = File(CALIBRATION_FILE_PATH, FILE_O_READ, InternalFS);
    if (f && f.size() == sizeof(StoredCalibration)) {
        f.read((uint8_t*)&g_cal, sizeof(g_cal));
        f.close();
        if (g_cal.magic == CAL_FILE_MAGIC) {
            DBG_PRINTLN("[CAL] Loaded calibration from flash");
            return;
        }
    }
    // Use defaults
    g_cal = {
        .magic        = CAL_FILE_MAGIC,
        .stepsPerMmH  = DEFAULT_STEPS_PER_MM_H,
        .stepsPerMmV  = DEFAULT_STEPS_PER_MM_V,
        .backlashH    = DEFAULT_BACKLASH_H,
        .backlashV    = DEFAULT_BACKLASH_V,
        .speedRPM     = SPEED_DRAW_DEFAULT_RPM,
        .maxStepsH    = DEFAULT_MAX_STEPS_H,
        .maxStepsV    = DEFAULT_MAX_STEPS_V,
    };
    DBG_PRINTLN("[CAL] Using default calibration");
}

static void saveCalibration() {
    InternalFS.remove(CALIBRATION_FILE_PATH);
    File f = File(CALIBRATION_FILE_PATH, FILE_O_WRITE, InternalFS);
    if (f) {
        f.write((uint8_t*)&g_cal, sizeof(g_cal));
        f.close();
        DBG_PRINTLN("[CAL] Calibration saved to flash");
    }
}

// Apply g_cal values to the motor controller and BLE service
static void applyCalibration() {
    motors.setSpeedRPM(g_cal.speedRPM);
    motors.setBacklash(g_cal.backlashH, g_cal.backlashV);

    // Update BLE calibration characteristic so iOS can read back current values
    CalibrationWireData wire = {
        (uint16_t)(g_cal.stepsPerMmH * 10.0f),
        (uint16_t)(g_cal.stepsPerMmV * 10.0f),
        g_cal.backlashH,
        g_cal.backlashV,
        g_cal.speedRPM,
        0, 0
    };
    bleService.setCalibrationValue(wire);
}

// ─────────────────────────────────────────────────────────────────────────────
// setup()
// ─────────────────────────────────────────────────────────────────────────────

void setup() {
#ifdef ETCHBOT_DEBUG
    Serial.begin(115200);
    while (!Serial && millis() < 3000) {}   // wait up to 3s for USB serial
    DBG_PRINTLN("[MAIN] EtchBot firmware starting");
#endif

    // 1. Load calibration from flash
    loadCalibration();

    // 2. Initialise motors
    if (!motors.begin()) {
        DBG_PRINTLN("[MAIN] FATAL: motors.begin() failed — check FeatherWing connection");
        // Flash the built-in LED rapidly as an error indicator
        while (true) {
            digitalWrite(LED_BUILTIN, HIGH); delay(100);
            digitalWrite(LED_BUILTIN, LOW);  delay(100);
        }
    }
    applyCalibration();

    // 3. Start BLE service
    bleService.begin();

    // 4. Indicate ready with a short LED flash
    for (int i = 0; i < 3; i++) {
        digitalWrite(LED_BUILTIN, HIGH); delay(150);
        digitalWrite(LED_BUILTIN, LOW);  delay(150);
    }

    DBG_PRINTLN("[MAIN] Setup complete — waiting for BLE connection");
}

// ─────────────────────────────────────────────────────────────────────────────
// loop() — cooperative state machine
// ─────────────────────────────────────────────────────────────────────────────

void loop() {

    // ── Process any pending BLE commands ──────────────────────────────────────

    // START_TRANSFER
    if (bleCmd.startTransfer) {
        bleCmd.startTransfer = false;
        pathStorage.beginTransfer(bleCmd.transferTotalBytes);
        bleService.notifyStatus(STATE_RECEIVING, 0, 0);
        bleService.notifyTransferStatus(0, 0, true);
    }

    // END_TRANSFER — verify CRC and report result
    if (bleCmd.endTransfer) {
        bleCmd.endTransfer = false;
        if (pathStorage.finalise()) {
            bleService.notifyStatus(STATE_IDLE, 0, pathStorage.header().moveCount);
            DBG_PRINTF("[MAIN] Transfer complete: %u moves ready\n",
                       pathStorage.header().moveCount);
        } else {
            bleService.notifyStatus(STATE_ERROR, 0, 0, /*errorCode=*/1);
            DBG_PRINTLN("[MAIN] Transfer FAILED: CRC or header error");
        }
    }

    // START_DRAWING
    if (bleCmd.startDrawing) {
        bleCmd.startDrawing = false;
        if (pathStorage.isValid() && !drawingExecutor.isRunning()) {
            drawingExecutor.prepare();
            DBG_PRINTLN("[MAIN] Drawing started");
        } else {
            DBG_PRINTLN("[MAIN] START_DRAWING ignored: no valid path or already drawing");
        }
    }

    // PAUSE
    if (bleCmd.pause) {
        bleCmd.pause = false;
        drawingExecutor.pause();
    }

    // RESUME
    if (bleCmd.resume) {
        bleCmd.resume = false;
        drawingExecutor.resume();
    }

    // CANCEL
    if (bleCmd.cancel) {
        bleCmd.cancel = false;
        drawingExecutor.cancel();
        pathStorage.reset();
    }

    // HOME
    if (bleCmd.home) {
        bleCmd.home = false;
        drawingExecutor.cancel();
        homing.run(g_cal.maxStepsH, g_cal.maxStepsV);
    }

    // CALIBRATE commands
    if (bleCmd.calibrateH) {
        bleCmd.calibrateH = false;
        calibration.drawHorizontalLine();
    }
    if (bleCmd.calibrateV) {
        bleCmd.calibrateV = false;
        calibration.drawVerticalLine();
    }
    if (bleCmd.calibrateBH) {
        bleCmd.calibrateBH = false;
        calibration.drawHorizontalBacklashPatterns();
    }
    if (bleCmd.calibrateBV) {
        bleCmd.calibrateBV = false;
        calibration.drawVerticalBacklashPatterns();
    }

    // SET_SPEED
    if (bleCmd.setSpeed) {
        bleCmd.setSpeed = false;
        g_cal.speedRPM = bleCmd.newSpeed;
        motors.setSpeedRPM(g_cal.speedRPM);
        saveCalibration();
    }

    // CALIBRATION WRITE from iOS
    if (bleCmd.calibrationWritten) {
        bleCmd.calibrationWritten = false;
        const CalibrationWireData& w = bleCmd.newCalibration;
        g_cal.stepsPerMmH = (float)w.stepsPerMmH_x10 / 10.0f;
        g_cal.stepsPerMmV = (float)w.stepsPerMmV_x10 / 10.0f;
        g_cal.backlashH   = w.backlashH;
        g_cal.backlashV   = w.backlashV;
        g_cal.speedRPM    = (uint8_t)w.speedRPM;
        g_cal.maxStepsH   = (uint16_t)(g_cal.stepsPerMmH * 175.0f);   // 175mm drawing width
        g_cal.maxStepsV   = (uint16_t)(g_cal.stepsPerMmV * 120.0f);   // 120mm drawing height
        applyCalibration();
        saveCalibration();
        DBG_PRINTF("[MAIN] Calibration updated: H=%.1f V=%.1f BL=%u/%u\n",
                   g_cal.stepsPerMmH, g_cal.stepsPerMmV,
                   g_cal.backlashH, g_cal.backlashV);
    }

    // ── Execute drawing ticks ─────────────────────────────────────────────────
    // Run a small batch of moves each loop iteration to keep BLE responsive.
    if (drawingExecutor.isRunning()) {
        drawingExecutor.tick(/*movesPerTick=*/10);
    }

    // ── Yield to BLE stack ────────────────────────────────────────────────────
    // The Adafruit nRF52 BLE stack runs in a FreeRTOS task.
    // Calling yield() or delayMicroseconds() lets it process events.
    yield();
}
