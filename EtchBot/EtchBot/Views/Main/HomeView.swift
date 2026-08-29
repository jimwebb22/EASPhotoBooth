// HomeView.swift — EtchBot
// Main screen. Shows the Etch-a-Sketch frame with action buttons below.

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var imageVM: ImageProcessingViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: — Etch-a-Sketch frame display
                    EtchASketchFrame(title: "EtchBot") {
                        Group {
                            if let preview = imageVM.previewImage {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 48))
                                        .foregroundColor(Color.etchDark.opacity(0.4))
                                    Text("Capture or select a photo\nto begin")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color.etchDark.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: — Action buttons
                    VStack(spacing: 12) {
                        // Primary: Take / Choose Photo
                        HStack(spacing: 12) {
                            ActionButton(
                                title: "Take Photo",
                                icon: "camera.fill",
                                style: .primary
                            ) {
                                coordinator.openCamera()
                            }
                            ActionButton(
                                title: "Choose Photo",
                                icon: "photo.on.rectangle",
                                style: .secondary
                            ) {
                                imageVM.showPhotoPicker = true
                            }
                        }

                        // Edit / Preview if photo selected
                        if imageVM.sourceImage != nil {
                            NavigationLink(destination: ImageEditorView()) {
                                Label("Edit & Preview", systemImage: "slider.horizontal.3")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.etchDark)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }

                        // Device status row
                        DeviceStatusRow()
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.openDeviceList()
                    } label: {
                        Image(systemName: deviceVM.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(deviceVM.isConnected ? .green : .secondary)
                    }
                    .accessibilityLabel(deviceVM.isConnected ? "Connected to \(deviceVM.connectedDeviceName)" : "Connect device")
                }
            }
            .sheet(isPresented: $imageVM.showPhotoPicker) {
                PhotoLibraryPicker { image in
                    imageVM.setSourceImage(image)
                }
            }
            .sheet(item: $coordinator.activeSheet) { sheet in
                switch sheet {
                case .camera:
                    CameraView()
                case .deviceList:
                    DeviceListView()
                case .drawingSession:
                    DrawingSessionView()
                case .calibration:
                    CalibrationWizardView()
                }
            }
        }
    }
}

// MARK: — Sub-views

private struct ActionButton: View {
    enum Style { case primary, secondary }
    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding()
                .background(style == .primary ? Color.etchRed : Color(.systemGray5))
                .foregroundColor(style == .primary ? .white : .primary)
                .cornerRadius(12)
        }
        .accessibilityLabel(title)
    }
}

private struct DeviceStatusRow: View {
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        Button {
            coordinator.openDeviceList()
        } label: {
            HStack {
                Circle()
                    .fill(deviceVM.isConnected ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(deviceVM.isConnected
                     ? "Connected: \(deviceVM.connectedDeviceName)"
                     : "No device connected — tap to pair")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .accessibilityLabel(deviceVM.isConnected
            ? "Device \(deviceVM.connectedDeviceName) connected"
            : "No device connected. Tap to open device list.")
    }
}
