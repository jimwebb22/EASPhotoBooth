// CameraView.swift — EtchBot
// Full camera capture view inside the Etch-a-Sketch frame.
// Supports front/rear toggle, flash, and photo-library fallback.

import SwiftUI
import AVFoundation

struct CameraView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var imageVM: ImageProcessingViewModel
    @State private var cameraVM = CameraViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Etch-a-Sketch frame containing the camera preview
                EtchASketchFrame(title: "EtchBot", showKnobs: false) {
                    ZStack {
                        if cameraVM.isCameraAuthorized && cameraVM.isSessionRunning {
                            CameraPreviewLayer(session: cameraVM.session)
                        } else if let captured = cameraVM.capturedImage {
                            Image(uiImage: captured)
                                .resizable()
                                .scaledToFill()
                        } else {
                            permissionPlaceholder
                        }
                        // Overlay: aspect-ratio guide
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            .padding(2)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Controls
                if let captured = cameraVM.capturedImage {
                    capturedControls(image: captured)
                } else {
                    cameraControls
                }
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { coordinator.closeSheet() }
                }
            }
            .task { await cameraVM.requestPermissionAndStart() }
            .onDisappear { cameraVM.stopSession() }
        }
    }

    // MARK: — Controls

    private var cameraControls: some View {
        HStack(alignment: .center, spacing: 40) {
            // Flash toggle
            Button {
                cameraVM.toggleFlash()
            } label: {
                Image(systemName: cameraVM.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel(cameraVM.flashMode == .on ? "Flash on" : "Flash off")

            // Shutter
            Button {
                cameraVM.capturePhoto()
            } label: {
                Circle()
                    .strokeBorder(Color.etchRed, lineWidth: 4)
                    .background(Circle().fill(Color.etchRed.opacity(0.15)))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().fill(Color.etchRed).frame(width: 56, height: 56))
            }
            .accessibilityLabel("Take photo")

            // Camera flip
            Button {
                cameraVM.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("Switch camera")
        }
        .padding(.vertical, 24)
    }

    private func capturedControls(image: UIImage) -> some View {
        HStack(spacing: 24) {
            Button("Retake") {
                cameraVM.retake()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button("Use Photo") {
                imageVM.setSourceImage(image)
                coordinator.closeSheet()
            }
            .buttonStyle(.borderedProminent)
            .tint(.etchRed)
        }
        .padding(.vertical, 24)
    }

    private var permissionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.etchDark.opacity(0.4))
            if !cameraVM.isCameraAuthorized {
                Text("Camera access denied.\nUse Choose Photo instead.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.etchDark.opacity(0.6))
            }
        }
    }
}
