// DrawingSessionView.swift — EtchBot
// Live monitoring of an active drawing session.
// Shows animated path preview and real-time progress.

import SwiftUI

struct DrawingSessionView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var sessionVM: DrawingSessionViewModel
    @EnvironmentObject var imageVM: ImageProcessingViewModel
    @State private var showCancelAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // MARK: — Animated drawing preview
                EtchASketchFrame(title: "EtchBot") {
                    Group {
                        if let points = imageVM.stipplePoints, !points.isEmpty {
                            DrawingPreviewView(
                                points: points,
                                progress: sessionVM.progressFraction
                            )
                        } else {
                            ZStack {
                                Color.etchGrey
                                ProgressView().tint(Color.etchDark)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // MARK: — Connection status badge
                connectionStatusBadge

                // MARK: — Progress bar
                if sessionVM.totalMoves > 0 {
                    DrawingProgressBar(
                        currentMove: sessionVM.currentMove,
                        totalMoves: sessionVM.totalMoves,
                        estimatedSecondsRemaining: sessionVM.estimatedSecondsRemaining
                    )
                    .padding(.horizontal)
                }

                // MARK: — Complete screen
                if sessionVM.isComplete {
                    DrawingCompleteView {
                        coordinator.closeSheet()
                    }
                }

                Spacer()

                // MARK: — Pause / Resume / Cancel
                if !sessionVM.isComplete {
                    HStack(spacing: 16) {
                        Button {
                            sessionVM.togglePause()
                        } label: {
                            Label(sessionVM.isPaused ? "Resume" : "Pause",
                                  systemImage: sessionVM.isPaused ? "play.fill" : "pause.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }

                        Button {
                            showCancelAlert = true
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Drawing in Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { coordinator.closeSheet() }
                }
            }
            .alert("Cancel Drawing?", isPresented: $showCancelAlert) {
                Button("Keep Drawing", role: .cancel) {}
                Button("Cancel Drawing", role: .destructive) { sessionVM.cancel() }
            } message: {
                Text("The EtchBot will stop immediately. The current drawing will be incomplete.")
            }
        }
    }

    private var connectionStatusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionVM.connectionColor)
                .frame(width: 10, height: 10)
            Text(sessionVM.connectionStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }
}
