// homing.cpp — EtchBot Firmware

#include "homing.h"
#include "motor_controller.h"
#include "ble_service.h"
#include <Arduino.h>

Homing homing;

void Homing::run(uint16_t maxStepsH, uint16_t maxStepsV) {
    _running = true;
    bleService.notifyStatus(STATE_HOMING, 0, 0);
    DBG_PRINTLN("[HOME] Homing started");

    // Set reduced homing speed
    const uint8_t savedSpeed = motors.speedRPM();
    motors.setSpeedRPM(SPEED_HOMING_RPM);

    // Calculate overshoot targets
    const uint32_t stepsH = (uint32_t)(maxStepsH * HOMING_OVERSHOOT_FACTOR);
    const uint32_t stepsV = (uint32_t)(maxStepsV * HOMING_OVERSHOOT_FACTOR);
    const uint32_t totalSteps = max(stepsH, stepsV);

    DBG_PRINTF("[HOME] Moving %lu H, %lu V steps toward stop\n", stepsH, stepsV);

    // Drive both axes simultaneously toward home (−X, −Y = BACKWARD)
    // We interleave individual steps from each axis to maintain
    // proportional speed on both. Use Bresenham to handle different step counts.
    uint32_t doneH = 0;
    uint32_t doneV = 0;
    int32_t  err   = (int32_t)stepsH - (int32_t)stepsV;

    // Notify BLE every 500 steps so iOS app shows progress
    const uint32_t notifyInterval = 500;
    uint32_t        nextNotify     = notifyInterval;

    for (uint32_t i = 0; i < totalSteps; i++) {
        // Bresenham: decide which axis steps this iteration
        bool moveX = (doneH < stepsH);
        bool moveY = (doneV < stepsV);

        if (moveX && moveY) {
            // Both need to move — use the error term
            if (err >= 0) { motors.stepX(-1); doneH++; err -= (int32_t)stepsV; }
            else           { motors.stepY(-1); doneV++; err += (int32_t)stepsH; }
        } else if (moveX) {
            motors.stepX(-1); doneH++;
        } else if (moveY) {
            motors.stepY(-1); doneV++;
        } else {
            break;  // both axes done
        }

        if (i >= nextNotify) {
            // Small yield to BLE stack
            yield();
            nextNotify += notifyInterval;
        }
    }

    // Reset logical position — we're now at (0, 0)
    motors.resetPosition();
    motors.setSpeedRPM(savedSpeed);
    _running = false;

    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[HOME] Homing complete — position reset to (0,0)");
}
