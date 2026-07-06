// motor_controller.cpp — EtchBot Firmware

#include "motor_controller.h"
#include <Adafruit_MotorShield.h>

// Global singleton
MotorController motors;

// Static Adafruit objects (allocated here, owned by the singleton)
static Adafruit_MotorShield shield;

// ─────────────────────────────────────────────────────────────────────────────
// Initialisation
// ─────────────────────────────────────────────────────────────────────────────

bool MotorController::begin() {
    _shield = &shield;

    if (!_shield->begin()) {
        DBG_PRINTLN("[MOTOR] ERROR: FeatherWing not found on I2C bus");
        return false;
    }

    _motorX = _shield->getStepper(MOTOR_STEPS_PER_REV, MOTOR_X_PORT);
    _motorY = _shield->getStepper(MOTOR_STEPS_PER_REV, MOTOR_Y_PORT);

    setSpeedRPM(_speedRPM);
    DBG_PRINTF("[MOTOR] Initialised at %u RPM\n", _speedRPM);
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Speed
// ─────────────────────────────────────────────────────────────────────────────

void MotorController::setSpeedRPM(uint8_t rpm) {
    if (rpm < SPEED_MIN_RPM) rpm = SPEED_MIN_RPM;
    if (rpm > SPEED_MAX_RPM) rpm = SPEED_MAX_RPM;
    _speedRPM = rpm;
    if (_motorX) _motorX->setSpeed(rpm);
    if (_motorY) _motorY->setSpeed(rpm);
    DBG_PRINTF("[MOTOR] Speed set to %u RPM\n", rpm);
}

// ─────────────────────────────────────────────────────────────────────────────
// Move command execution (with backlash compensation)
// ─────────────────────────────────────────────────────────────────────────────

void MotorController::move(StepDir dir, uint16_t steps) {
    if (!_motorX || !_motorY) return;

    const int8_t sx = xSign(dir);
    const int8_t sy = ySign(dir);

    // ── Backlash compensation (firmware is the SOLE owner) ──────────────────
    // Inject slack take-up steps when an axis reverses direction. The iOS app
    // sends purely geometric paths and never pre-compensates; the values used
    // here arrive via the BLE calibration write. Slack take-up steps must not
    // change the logical pen position (_posX/_posY track the pen, not the
    // motor shaft), so they are stepped without position bookkeeping.
    if (sx != 0 && _lastDirX != 0 && sx != _lastDirX) {
        uint16_t bl = _backlashH;
        DBG_PRINTF("[MOTOR] X backlash: %u steps %s\n", bl, sx > 0 ? "FORWARD" : "BACKWARD");
        for (uint16_t i = 0; i < bl; i++) {
            _stepX(sx > 0 ? FORWARD : BACKWARD);
        }
    }
    if (sy != 0 && _lastDirY != 0 && sy != _lastDirY) {
        uint16_t bl = _backlashV;
        DBG_PRINTF("[MOTOR] Y backlash: %u steps %s\n", bl, sy > 0 ? "FORWARD" : "BACKWARD");
        for (uint16_t i = 0; i < bl; i++) {
            _stepY(sy > 0 ? FORWARD : BACKWARD);
        }
    }

    // Update last direction trackers
    if (sx != 0) _lastDirX = sx;
    if (sy != 0) _lastDirY = sy;

    // ── Execute the move ──────────────────────────────────────────────────────
    if (sx != 0 && sy == 0) {
        // Pure horizontal
        uint8_t arduinoDir = sx > 0 ? FORWARD : BACKWARD;
        for (uint16_t i = 0; i < steps; i++) {
            _stepX(arduinoDir);
            _posX += sx;
        }
    } else if (sx == 0 && sy != 0) {
        // Pure vertical
        uint8_t arduinoDir = sy > 0 ? FORWARD : BACKWARD;
        for (uint16_t i = 0; i < steps; i++) {
            _stepY(arduinoDir);
            _posY += sy;
        }
    } else if (sx != 0 && sy != 0) {
        // Diagonal: interleave X and Y steps (Bresenham-style, equal steps both axes)
        uint8_t adirX = sx > 0 ? FORWARD : BACKWARD;
        uint8_t adirY = sy > 0 ? FORWARD : BACKWARD;
        for (uint16_t i = 0; i < steps; i++) {
            _stepX(adirX);
            _stepY(adirY);
            _posX += sx;
            _posY += sy;
        }
    }
}

void MotorController::stepX(int8_t sign) {
    if (!_motorX) return;
    _stepX(sign > 0 ? FORWARD : BACKWARD);
    _posX += sign;
    if (sign != 0) _lastDirX = sign;
}

void MotorController::stepY(int8_t sign) {
    if (!_motorY) return;
    _stepY(sign > 0 ? FORWARD : BACKWARD);
    _posY += sign;
    if (sign != 0) _lastDirY = sign;
}

void MotorController::_stepX(uint8_t dir) {
    _motorX->step(1, dir, MOTOR_STEP_TYPE);
}

void MotorController::_stepY(uint8_t dir) {
    _motorY->step(1, dir, MOTOR_STEP_TYPE);
}

// ─────────────────────────────────────────────────────────────────────────────
// Position / enable / calibration
// ─────────────────────────────────────────────────────────────────────────────

void MotorController::resetPosition() {
    _posX    = 0;
    _posY    = 0;
    _lastDirX = 0;
    _lastDirY = 0;
    DBG_PRINTLN("[MOTOR] Position reset to (0,0)");
}

void MotorController::release() {
    if (_motorX) _motorX->release();
    if (_motorY) _motorY->release();
}

void MotorController::engage() {
    // Stepping immediately re-engages coils; no explicit enable needed for TB6612.
}

void MotorController::setBacklash(uint16_t h, uint16_t v) {
    _backlashH = h;
    _backlashV = v;
    DBG_PRINTF("[MOTOR] Backlash set: H=%u V=%u steps\n", h, v);
}

// ─────────────────────────────────────────────────────────────────────────────
// Direction sign helpers
// ─────────────────────────────────────────────────────────────────────────────
//   DIR_EAST=0 → (+1, 0)  DIR_NE=1 → (+1,+1)  DIR_NORTH=2 → (0,+1)
//   DIR_NW=3   → (-1,+1)  DIR_WEST=4 → (-1,0)  DIR_SW=5 → (-1,-1)
//   DIR_SOUTH=6 → (0,-1)  DIR_SE=7 → (+1,-1)

static const int8_t DX_TABLE[8] = { 1,  1, 0, -1, -1, -1,  0,  1};
static const int8_t DY_TABLE[8] = { 0,  1, 1,  1,  0, -1, -1, -1};

int8_t MotorController::xSign(StepDir d) { return DX_TABLE[d & 0x07]; }
int8_t MotorController::ySign(StepDir d) { return DY_TABLE[d & 0x07]; }
