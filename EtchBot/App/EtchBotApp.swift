// EtchBotApp.swift — EtchBot
// SwiftUI app entry point.

import SwiftUI

@main
struct EtchBotApp: App {

    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.bleManager)
                .environmentObject(coordinator.deviceViewModel)
                .environmentObject(coordinator.imageProcessingViewModel)
        }
    }
}

// MARK: — Content root (handles deep-link routing)

struct ContentRootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        HomeView()
    }
}
