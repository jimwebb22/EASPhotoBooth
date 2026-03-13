// motor_controller.h — EtchBot Firmware
// Stepper motor abstraction for the Adafruit DC Motor + Stepper FeatherWing.
// Wraps the Adafruit Motor Shield V2 library with:
//   - Named axis control (X = horizontal, Y = vertical)
//   - Firmware-side backlash compensation (secondary layer to iOS pre-compensation)
//   - Speed control
//   - Position tracking
//   - Safe enable/disable

#pragma once
#include <stdint.h>
#include "config.h"

// Forward declarations (avoid including heavy headers here)
class Adafruit_MotorShield;
class Adafruit_StepperMotor;

// ─────────────────────────────────────────────────────────────────────────────
// Direction enum (matches iOS StepDirection encoding)
// ─────────────────────────────────────────────────────────────────────────────

enum StepDir : uint8_t {
    DIR_EAST      = 0,   // +X
    DIR_NORTHEAST = 1,   // +X, +Y
    DIR_NORTH     = 2,   // +Y
    DIR_NORTHWEST = 3,   // -X, +Y
    DIR_WEST      = 4,   // -X
    DIR_SOUTHWEST = 5,   // -X, -Y
    DIR_SOUTH     = 6,   // -Y
    DIR_SOUTHEAST = 7,   // +X, -Y
};

// ─────────────────────────────────────────────────────────────────────────────
// MotorController
// ─────────────────────────────────────────────────────────────────────────────

class MotorController {
public:
    // Call once in setup() — initialises I2C FeatherWing, sets speed.
    // Returns false if FeatherWing not detected.
    bool begin();

    // Set motor speed in RPM (clamped to SPEED_MIN/MAX_RPM).
    void setSpeedRPM(uint8_t rpm);
    uint8_t speedRPM() const { return _speedRPM; }

    // Execute one move command: move `steps` steps in `dir`.
    // Applies firmware-side backlash compensation on axis reversals.
    void move(StepDir dir, uint16_t steps);

    // Move a single step on one or both axes (used internally for diagonal moves).
    void stepX(int8_t sign);   // sign: +1 = forward (+X), -1 = backward (-X)
    void stepY(int8_t sign);

    // Retrieve current logical position (steps from home, unsigned)
    int32_t posX() const { return _posX; }
    int32_t posY() const { return _posY; }
    void resetPosition();      // set (0,0) — call after homing

    // Release motor coils to stop holding current (call when idle/done).
    void release();

    // Re-enable motor coils.
    void engage();

    // Calibration values (set from stored CalibrationData on startup / after BLE write)
    void setBacklash(uint16_t backlashH, uint16_t backlashV);

private:
    Adafruit_MotorShield* _shield  = nullptr;
    Adafruit_StepperMotor* _motorX = nullptr;
    Adafruit_StepperMotor* _motorY = nullptr;

    uint8_t  _speedRPM      = SPEED_DRAW_DEFAULT_RPM;
    int8_t   _lastDirX      = 0;   // last X direction: -1, 0, +1
    int8_t   _lastDirY      = 0;   // last Y direction
    int32_t  _posX          = 0;
    int32_t  _posY          = 0;
    uint16_t _backlashH     = DEFAULT_BACKLASH_H;
    uint16_t _backlashV     = DEFAULT_BACKLASH_V;

    // Direction sign helpers
    static int8_t xSign(StepDir d);
    static int8_t ySign(StepDir d);

    // Low-level single step (calls Adafruit library)
    void _stepX(uint8_t arduinoDir);
    void _stepY(uint8_t arduinoDir);
};

extern MotorController motors;
