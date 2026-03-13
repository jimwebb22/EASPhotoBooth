// calibration.h — EtchBot Firmware
// Calibration pattern drawing routines triggered by the iOS calibration wizard.
//
// Patterns drawn (blocking operations):
//   CALIBRATE_H  — horizontal reference line (CALIBRATION_LINE_STEPS east)
//   CALIBRATE_V  — vertical reference line (CALIBRATION_LINE_STEPS north)
//   CALIBRATE_BH — 5 horizontal back-and-forth patterns with varying backlash (0,30,60,90,120 steps)
//   CALIBRATE_BV — same patterns on vertical axis
//
// After each pattern, the stylus is left in place for the user to photograph / measure.
// All routines use motors.move() directly (bypassing the path buffer).

#pragma once
#include <stdint.h>
#include "config.h"

class Calibration {
public:
    // Draw a straight horizontal reference line of CALIBRATION_LINE_STEPS steps.
    void drawHorizontalLine();

    // Draw a straight vertical reference line.
    void drawVerticalLine();

    // Draw 5 horizontal back-and-forth segments with different backlash injections.
    // The patterns are arranged vertically so all 5 are visible simultaneously.
    void drawHorizontalBacklashPatterns();

    // Same for vertical axis.
    void drawVerticalBacklashPatterns();

private:
    // Draw one back-and-forth pattern with a given backlash injection.
    // `backlashSteps`: extra steps injected on direction reversal.
    // `segmentSteps`: half-width of the pattern.
    // `offsetSteps`: how far to move on the perpendicular axis before drawing (gap).
    void drawBacklashSegment(bool isHorizontal, uint16_t backlashSteps,
                             uint16_t segmentSteps, uint16_t offsetSteps);
};

extern Calibration calibration;
