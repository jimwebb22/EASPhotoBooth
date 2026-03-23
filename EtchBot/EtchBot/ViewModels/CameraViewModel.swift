// CameraViewModel.swift — EtchBot
// Manages AVCaptureSession for the camera view.

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
public final class CameraViewModel: ObservableObject {

    // MARK: — Published state
    @Published public var capturedImage: UIImage?
    @Published public var isCameraAuthorized: Bool = false
    @Published public var isSessionRunning: Bool = false
    @Published public var flashMode: AVCaptureDevice.FlashMode = .off
    @Published public var currentCameraPosition: AVCaptureDevice.Position = .back

    // MARK: — AVFoundation
    public let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoCompletion: ((UIImage?) -> Void)?

    // MARK: — Permission + setup

    public func requestPermissionAndStart() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isCameraAuthorized = true
            await startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isCameraAuthorized = granted
            if granted { await startSession() }
        default:
            isCameraAuthorized = false
        }
    }

    // MARK: — Session management

    private func startSession() async {
        guard !session.isRunning else { return }
        await setupSession(position: currentCameraPosition)
        let captureSession = session
        Task.detached {
            captureSession.startRunning()
            await MainActor.run { [weak self] in self?.isSessionRunning = true }
        }
    }

    public func stopSession() {
        let captureSession = session
        Task.detached {
            captureSession.stopRunning()
            await MainActor.run { [weak self] in self?.isSessionRunning = false }
        }
    }

    private func setupSession(position: AVCaptureDevice.Position) async {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Remove existing input
        if let input = currentInput {
            session.removeInput(input)
            currentInput = nil
        }

        // Add camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        // Add photo output
        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }

        session.commitConfiguration()
    }

    // MARK: — Controls

    public func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    public func flipCamera() {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        Task { await setupSession(position: currentCameraPosition) }
    }

    public func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = currentCameraPosition == .back ? flashMode : .off
        photoOutput.capturePhoto(with: settings, delegate: PhotoDelegate { [weak self] image in
            Task { @MainActor [weak self] in self?.capturedImage = image }
        })
    }

    public func retake() {
        capturedImage = nil
    }
}

// MARK: — Photo delegate

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    let completion: @Sendable (UIImage?) -> Void
    init(completion: @Sendable @escaping (UIImage?) -> Void) { self.completion = completion }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            completion(nil); return
        }
        completion(UIImage(data: data))
    }
}
