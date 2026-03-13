// drawing_executor.h — EtchBot Firmware
// Reads the validated path buffer and drives the motors to execute the drawing.
// Designed as a cooperative state machine: call tick() from the main loop
// so BLE callbacks can still fire between move batches.

#pragma once
#include <stdint.h>
#include "config.h"
#include "ble_service.h"

class DrawingExecutor {
public:
    // Prepare for a new drawing using the current path_storage contents.
    // Call after pathStorage.finalise() returns true.
    void prepare();

    // Execute up to `movesPerTick` move commands per call.
    // Returns true if drawing is still in progress, false when complete.
    bool tick(uint16_t movesPerTick = 10);

    // Pause execution (motors hold position, no more ticks until resume).
    void pause();
    void resume();
    bool isPaused()    const { return _paused; }
    bool isComplete()  const { return _complete; }
    bool isRunning()   const { return _running && !_paused && !_complete; }

    // Stop and discard current drawing.
    void cancel();

    // Progress accessors (for BLE status notifications)
    uint16_t currentMoveIndex() const { return _moveIdx; }
    uint16_t totalMoves()       const { return _totalMoves; }

private:
    bool     _running   = false;
    bool     _paused    = false;
    bool     _complete  = false;
    uint16_t _moveIdx   = 0;
    uint16_t _totalMoves = 0;

    // Pointer into the path buffer payload (after 12-byte header)
    const uint8_t* _payload = nullptr;

    // Timestamp of last BLE status notification
    uint32_t _lastNotifyMs    = 0;
    uint16_t _movesSinceNotify = 0;

    // Decode a 2-byte move command at payload offset i*2
    void decodeMove(uint16_t index, StepDir& dir, uint16_t& runLen) const;

    // Send a status notification if interval thresholds are met
    void maybeNotifyStatus();
};

extern DrawingExecutor drawingExecutor;
