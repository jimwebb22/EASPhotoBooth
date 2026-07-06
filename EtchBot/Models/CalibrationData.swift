// CalibrationData.swift — EtchBot
// Per-device calibration values measured via the Calibration Wizard.

import Foundation

/// Calibration values for a specific EtchBot hardware device.
/// Stored per-device keyed by BLE peripheral identifier UUID string.
public struct CalibrationData: Codable, Sendable, Equatable {
    // MARK: — Steps per millimetre
    /// Number of motor steps per millimetre of travel, horizontal axis.
    /// Default: 40 steps/mm (NEMA 17, GT2 belt, typical ratio).
    public var stepsPerMmHorizontal: Double

    /// Number of motor steps per millimetre of travel, vertical axis.
    public var stepsPerMmVertical: Double

    // MARK: — Backlash compensation
    /// Slack take-up steps applied by the FIRMWARE when the horizontal axis
    /// reverses direction. The app never injects these into the encoded path;
    /// it only syncs the value to the device via the BLE calibration write.
    /// Default 60 steps (~1.5mm at 40 steps/mm) is a placeholder until
    /// measured with the calibration wizard on real hardware.
    public var backlashHorizontalSteps: Int

    /// Firmware slack take-up steps for vertical axis reversals (see above).
    public var backlashVerticalSteps: Int

    // MARK: — Home offset
    /// Steps from physical home position to the true (0, 0) drawing origin.
    public var homeOffsetX: Int
    public var homeOffsetY: Int

    // MARK: — Drawing area dimensions (computed from calibration)
    /// Width of drawing area in steps = stepsPerMm * 175mm (typical Etch-a-Sketch).
    public var drawingAreaWidthSteps: Int {
        Int(stepsPerMmHorizontal * 175.0)
    }

    /// Height of drawing area in steps = stepsPerMm * 120mm.
    public var drawingAreaHeightSteps: Int {
        Int(stepsPerMmVertical * 120.0)
    }

    // MARK: — Motor speed
    /// Motor drawing speed in RPM. Default: 100. Range: 20–200.
    public var drawingSpeedRPM: Int

    // MARK: — Calibration state
    /// Whether this device has been through the calibration wizard.
    public var isCalibrated: Bool

    // MARK: — Defaults
    public static let defaults = CalibrationData(
        stepsPerMmHorizontal: 40.0,
        stepsPerMmVertical: 40.0,
        backlashHorizontalSteps: 60,
        backlashVerticalSteps: 60,
        homeOffsetX: 0,
        homeOffsetY: 0,
        drawingSpeedRPM: 100,
        isCalibrated: false
    )

    public init(
        stepsPerMmHorizontal: Double = 40.0,
        stepsPerMmVertical: Double = 40.0,
        backlashHorizontalSteps: Int = 60,
        backlashVerticalSteps: Int = 60,
        homeOffsetX: Int = 0,
        homeOffsetY: Int = 0,
        drawingSpeedRPM: Int = 100,
        isCalibrated: Bool = false
    ) {
        self.stepsPerMmHorizontal = stepsPerMmHorizontal
        self.stepsPerMmVertical = stepsPerMmVertical
        self.backlashHorizontalSteps = backlashHorizontalSteps
        self.backlashVerticalSteps = backlashVerticalSteps
        self.homeOffsetX = homeOffsetX
        self.homeOffsetY = homeOffsetY
        self.drawingSpeedRPM = drawingSpeedRPM
        self.isCalibrated = isCalibrated
    }
}
