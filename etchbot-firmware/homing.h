// homing.h — EtchBot Firmware
// Homing routine: drive both axes to the bottom-left mechanical stop
// using the overshoot method (no limit switches required).
//
// Strategy:
//   Drive both motors toward home (−X, −Y) at reduced speed for
//   (maxTravel × HOMING_OVERSHOOT_FACTOR) steps.
//   The worm-gear inside the Etch-a-Sketch absorbs extra steps when
//   the stylus is already against the stop — no damage occurs.
//   After completion, reset the position counter to (0, 0).

#pragma once
#include <stdint.h>
#include "config.h"

class Homing {
public:
    // Execute synchronous homing. Blocks until complete.
    // Sends BLE status updates during the process.
    // `maxStepsH` / `maxStepsV` come from the current calibration data.
    void run(uint16_t maxStepsH = DEFAULT_MAX_STEPS_H,
             uint16_t maxStepsV = DEFAULT_MAX_STEPS_V);

    bool isRunning() const { return _running; }

private:
    bool _running = false;
};

extern Homing homing;
