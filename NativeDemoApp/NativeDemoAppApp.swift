import SwiftUI

@main
struct NativeDemoAppApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            AppThemeRootView(settingsViewModel: settingsViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(homeViewModel)
                .preferredColorScheme(settingsViewModel.colorScheme)
        }
    }
}

/// Read the effective window appearance inside the view hierarchy, not at App
/// scope. This is the only production owner of resolved-theme updates.
@MainActor
private struct AppThemeRootView: View {
    @Environment(\.colorScheme) private var effectiveColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var themeResolver = ThemeResolver.shared

    private struct Configuration: Equatable {
        let themeID: String
        let appearance: AppSettings.Appearance
        let colorScheme: ColorScheme
    }

    private var configuration: Configuration {
        Configuration(
            themeID: settingsViewModel.settings.colorThemeId,
            appearance: settingsViewModel.appearance,
            colorScheme: effectiveColorScheme
        )
    }

    var body: some View {
        ContentView()
            .appTheme(themeResolver.colors)
            .onAppear(perform: synchronizeTheme)
            .onChange(of: configuration) { _, _ in
                synchronizeTheme()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    synchronizeTheme()
                }
            }
    }

    private func synchronizeTheme() {
        themeResolver.apply(
            themeId: configuration.themeID,
            appearance: configuration.appearance,
            systemColorScheme: configuration.colorScheme
        )
    }
}
