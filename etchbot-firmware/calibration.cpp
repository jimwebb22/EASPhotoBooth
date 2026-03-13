// calibration.cpp — EtchBot Firmware

#include "calibration.h"
#include "motor_controller.h"
#include "ble_service.h"
#include <Arduino.h>

Calibration calibration;

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal reference line
// ─────────────────────────────────────────────────────────────────────────────

void Calibration::drawHorizontalLine() {
    bleService.notifyStatus(STATE_CALIBRATING, 0, 0);
    DBG_PRINTF("[CAL] Drawing H line: %u steps east\n", CALIBRATION_LINE_STEPS);
    motors.move(DIR_EAST, CALIBRATION_LINE_STEPS);
    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[CAL] H line complete");
}

// ─────────────────────────────────────────────────────────────────────────────
// Vertical reference line
// ─────────────────────────────────────────────────────────────────────────────

void Calibration::drawVerticalLine() {
    bleService.notifyStatus(STATE_CALIBRATING, 0, 0);
    DBG_PRINTF("[CAL] Drawing V line: %u steps north\n", CALIBRATION_LINE_STEPS);
    motors.move(DIR_NORTH, CALIBRATION_LINE_STEPS);
    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[CAL] V line complete");
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal backlash test patterns
// Five patterns, stacked vertically with gaps between them.
// Each pattern: move east, reverse west, observe alignment.
// ─────────────────────────────────────────────────────────────────────────────

void Calibration::drawHorizontalBacklashPatterns() {
    bleService.notifyStatus(STATE_CALIBRATING, 0, 0);
    DBG_PRINTLN("[CAL] Drawing H backlash patterns");

    // Move away from home to give a clear baseline
    motors.move(DIR_NORTH, BACKLASH_TEST_GAP_STEPS);

    for (int p = 0; p < BACKLASH_TEST_PATTERN_COUNT; p++) {
        drawBacklashSegment(
            /*isHorizontal=*/true,
            BACKLASH_TEST_VALUES[p],
            BACKLASH_TEST_SEGMENT_STEPS,
            BACKLASH_TEST_GAP_STEPS
        );
        yield();  // Allow BLE to breathe between patterns
    }

    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[CAL] H backlash patterns complete");
}

// ─────────────────────────────────────────────────────────────────────────────
// Vertical backlash test patterns (stacked horizontally)
// ─────────────────────────────────────────────────────────────────────────────

void Calibration::drawVerticalBacklashPatterns() {
    bleService.notifyStatus(STATE_CALIBRATING, 0, 0);
    DBG_PRINTLN("[CAL] Drawing V backlash patterns");

    motors.move(DIR_EAST, BACKLASH_TEST_GAP_STEPS);

    for (int p = 0; p < BACKLASH_TEST_PATTERN_COUNT; p++) {
        drawBacklashSegment(
            /*isHorizontal=*/false,
            BACKLASH_TEST_VALUES[p],
            BACKLASH_TEST_SEGMENT_STEPS,
            BACKLASH_TEST_GAP_STEPS
        );
        yield();
    }

    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[CAL] V backlash patterns complete");
}

// ─────────────────────────────────────────────────────────────────────────────
// drawBacklashSegment — one back-and-forth with explicit backlash injection
// ─────────────────────────────────────────────────────────────────────────────
//
// For a horizontal pattern (isHorizontal=true):
//   1. Draw a line east (segmentSteps)
//   2. Inject backlashSteps east (overshoot before reversing)
//   3. Draw a line west (segmentSteps) — these two lines should align if
//      backlashSteps matches the actual mechanical backlash
//   4. Move north (offsetSteps) — gap before next pattern
//
// For vertical, substitute north/south for east/west.

void Calibration::drawBacklashSegment(bool isHorizontal, uint16_t backlashSteps,
                                       uint16_t segmentSteps, uint16_t offsetSteps) {
    const StepDir fwd    = isHorizontal ? DIR_EAST  : DIR_NORTH;
    const StepDir rev    = isHorizontal ? DIR_WEST  : DIR_SOUTH;
    const StepDir offset = isHorizontal ? DIR_NORTH : DIR_EAST;

    DBG_PRINTF("[CAL] Backlash segment: bl=%u, seg=%u\n", backlashSteps, segmentSteps);

    // Forward pass
    motors.move(fwd, segmentSteps);

    // Inject explicit backlash overshoot (bypass firmware's automatic compensation
    // by temporarily using the raw stepX/stepY calls wouldn't work, so instead we
    // directly drive extra steps in the SAME forward direction, then reverse)
    if (backlashSteps > 0) {
        motors.move(fwd, backlashSteps);
    }

    // Reverse pass — the firmware's backlash compensation is disabled for this
    // function because we're explicitly controlling the backlash.
    motors.move(rev, segmentSteps + backlashSteps);

    // Gap to next pattern
    motors.move(offset, offsetSteps);
}
