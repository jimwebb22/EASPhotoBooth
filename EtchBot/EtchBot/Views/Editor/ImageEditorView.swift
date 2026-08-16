// ImageEditorView.swift — EtchBot
// Post-capture editing: adjust density/contrast, preview the TSP drawing,
// and send to the EtchBot device.

import SwiftUI

struct ImageEditorView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var imageVM: ImageProcessingViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: — Drawing Preview in Etch-a-Sketch frame
                EtchASketchFrame(title: "EtchBot") {
                    ZStack {
                        if let points = imageVM.stipplePoints, !points.isEmpty {
                            DrawingPreviewView(points: points)
                        } else if imageVM.isProcessing {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(Color.etchDark)
                                Text("Processing…")
                                    .font(.caption)
                                    .foregroundColor(Color.etchDark.opacity(0.6))
                            }
                        } else if let img = imageVM.sourceImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .opacity(0.4)
                        }
                    }
                }
                .padding(.horizontal)

                // MARK: — Processing progress overlay
                if imageVM.isProcessing {
                    ProcessingProgressView(
                        phase: imageVM.currentPhase,
                        progress: imageVM.processingProgress,
                        detail: imageVM.processingDetail
                    )
                }

                // MARK: — Settings panel
                DensitySliderView(settings: $imageVM.settings)
                    .padding(.horizontal)
                    .onChange(of: imageVM.settings) { _, newSettings in
                        imageVM.reprocessDebounced()
                    }

                // MARK: — Estimated time
                if imageVM.stipplePoints != nil {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("Estimated drawing time: ~\(imageVM.settings.estimatedDrawTimeMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // MARK: — Action buttons
                VStack(spacing: 12) {
                    // Send to EtchBot
                    Button {
                        Task { await sendToDevice() }
                    } label: {
                        Label("Send to EtchBot", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(deviceVM.isConnected ? Color.etchRed : Color.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!deviceVM.isConnected || imageVM.drawingPath == nil)
                    .accessibilityLabel(deviceVM.isConnected
                        ? "Send drawing to EtchBot"
                        : "No device connected. Connect a device first.")
                    .accessibilityHint(deviceVM.isConnected ? "" : "Go to Devices to connect an EtchBot.")

                    if !deviceVM.isConnected {
                        Text("Connect an EtchBot device to send the drawing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Save preview
                    Button {
                        imageVM.savePreviewToPhotoLibrary()
                    } label: {
                        Label("Save Preview", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .disabled(imageVM.stipplePoints == nil)
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Edit & Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if imageVM.stipplePoints == nil, imageVM.sourceImage != nil {
                await imageVM.processImage()
            }
        }
    }

    private func sendToDevice() async {
        guard let path = imageVM.drawingPath,
              let connection = coordinator.bleManager.connectedDevice else { return }
        do {
            try await coordinator.transferService.transferAndStart(path: path, connection: connection)
            coordinator.openDrawingSession()
        } catch {
            imageVM.transferError = error.localizedDescription
        }
    }
}
