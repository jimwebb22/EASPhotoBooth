// config.h — EtchBot Firmware
// Pin definitions, compile-time constants, and default calibration values.
// Edit this file to match your specific hardware build.
//
// Target: Adafruit Feather nRF52840 Express + DC Motor + Stepper FeatherWing
// Board package: Adafruit nRF52 BSP (https://adafruit.github.io/arduino-board-index/package_adafruit_index.json)
// Required libraries:
//   - Adafruit Motor Shield V2 Library
//   - Adafruit Bluefruit nRF52 Libraries (bundled with BSP)
//   - Adafruit LittleFS (bundled with BSP)

#pragma once
#include <stdint.h>

// ─────────────────────────────────────────────────────────────────────────────
// Motor Configuration
// ─────────────────────────────────────────────────────────────────────────────

// Stepper FeatherWing motor port assignments:
//   Port 1 (M1+M2) = Horizontal axis (X, left knob)
//   Port 2 (M3+M4) = Vertical axis   (Y, right knob)
#define MOTOR_X_PORT          1
#define MOTOR_Y_PORT          2

// Steps per full revolution for connected stepper motors.
// NEMA 17 standard: 200 steps/rev (1.8° per step).
#define MOTOR_STEPS_PER_REV   200

// Microstepping mode for Adafruit Motor Shield V2 library.
// Options: SINGLE, DOUBLE, INTERLEAVED, MICROSTEP
// MICROSTEP = 8 microsteps per full step → 1600 microsteps/rev
// Use INTERLEAVED for a good balance of torque and smoothness without microstep loss.
#define MOTOR_STEP_TYPE       MICROSTEP

// ─────────────────────────────────────────────────────────────────────────────
// Speed Settings (RPM)
// ─────────────────────────────────────────────────────────────────────────────

#define SPEED_DRAW_DEFAULT_RPM   100    // Normal drawing speed
#define SPEED_HOMING_RPM          50    // Gentle homing speed (reduced to avoid damage)
#define SPEED_CALIBRATION_RPM     80    // Speed during calibration pattern drawing
#define SPEED_MIN_RPM             20    // Minimum settable via BLE SET_SPEED command
#define SPEED_MAX_RPM            200    // Maximum settable via BLE SET_SPEED command

// ─────────────────────────────────────────────────────────────────────────────
// Default Calibration Values  (overridden by CalibrationData stored in flash)
// ─────────────────────────────────────────────────────────────────────────────

// Steps per millimetre of physical travel.
// At MICROSTEP mode: 1600 microsteps/rev ÷ (GT2 20-tooth pulley, 40mm/rev) = 40 steps/mm.
// Adjust after running the calibration wizard.
#define DEFAULT_STEPS_PER_MM_H    40.0f   // horizontal (X) axis
#define DEFAULT_STEPS_PER_MM_V    40.0f   // vertical   (Y) axis

// Backlash compensation in steps.
// Default 60 steps ≈ 1.5mm at 40 steps/mm — typical Etch-a-Sketch worm gear.
#define DEFAULT_BACKLASH_H        60
#define DEFAULT_BACKLASH_V        60

// Drawing area maximum travel in steps (derived from steps/mm × physical dimension).
// Classic Etch-a-Sketch drawing area: 175mm × 120mm.
#define DEFAULT_MAX_STEPS_H       7000   // 175mm × 40 steps/mm
#define DEFAULT_MAX_STEPS_V       4800   // 120mm × 40 steps/mm

// Homing overshoot factor: move (factor × max_travel) steps toward the stop.
// 1.1 = 110% of max travel, ensuring the stylus always reaches the corner.
#define HOMING_OVERSHOOT_FACTOR   1.10f

// ─────────────────────────────────────────────────────────────────────────────
// Path Buffer
// ─────────────────────────────────────────────────────────────────────────────

// 50KB RAM buffer for the drawing path.
// nRF52840 has 256KB RAM; BLE stack + app overhead ≈ 80KB → ~176KB available.
#define PATH_BUFFER_SIZE          (50u * 1024u)   // 51200 bytes

// Binary path header size (matches iOS DrawingPathEncoder)
#define PATH_HEADER_SIZE          12u
#define PATH_MAGIC_BYTE_0         0xEB
#define PATH_MAGIC_BYTE_1         0x01

// ─────────────────────────────────────────────────────────────────────────────
// BLE Timing
// ─────────────────────────────────────────────────────────────────────────────

// Send a Device Status notification after every N move commands executed.
#define STATUS_NOTIFY_MOVE_INTERVAL   100

// Also notify at least every N milliseconds even if move count hasn't been reached.
#define STATUS_NOTIFY_MS_INTERVAL     2000

// Delay (ms) between chunks during BLE transfer — allows BLE stack to breathe.
#define TRANSFER_CHUNK_DELAY_MS       5

// ─────────────────────────────────────────────────────────────────────────────
// Calibration Pattern Parameters
// ─────────────────────────────────────────────────────────────────────────────

// Steps in the calibration reference line (matches iOS CalibrationViewModel.calibrationLineSteps)
#define CALIBRATION_LINE_STEPS        4000

// Backlash test: number of patterns drawn for each axis (0,30,60,90,120 steps)
#define BACKLASH_TEST_PATTERN_COUNT   5
static const uint16_t BACKLASH_TEST_VALUES[BACKLASH_TEST_PATTERN_COUNT] = {0, 30, 60, 90, 120};

// Steps per back-and-forth segment in backlash test pattern
#define BACKLASH_TEST_SEGMENT_STEPS   500
// Gap between patterns (step units)
#define BACKLASH_TEST_GAP_STEPS       200

// ─────────────────────────────────────────────────────────────────────────────
// Persistent Storage
// ─────────────────────────────────────────────────────────────────────────────

// Filename in the internal LittleFS flash filesystem
#define CALIBRATION_FILE_PATH         "/etchbot_cal.bin"

// Calibration file magic word (used to detect valid stored data)
#define CAL_FILE_MAGIC                0xEB02u

// ─────────────────────────────────────────────────────────────────────────────
// Debug
// ─────────────────────────────────────────────────────────────────────────────

// Uncomment to enable verbose Serial output (9600 baud on USB)
#define ETCHBOT_DEBUG

#ifdef ETCHBOT_DEBUG
  #include <Arduino.h>
  #define DBG_PRINT(x)    Serial.print(x)
  #define DBG_PRINTLN(x)  Serial.println(x)
  #define DBG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define DBG_PRINT(x)
  #define DBG_PRINTLN(x)
  #define DBG_PRINTF(...)
#endif
