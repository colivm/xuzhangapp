import SwiftUI

@main
struct NativeDemoAppApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsViewModel)
                .environmentObject(homeViewModel)
                .preferredColorScheme(settingsViewModel.colorScheme)
        }
    }
}

