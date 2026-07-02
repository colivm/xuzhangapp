import SwiftUI

@main
struct NativeDemoAppApp: App {
    @Environment(\.colorScheme) private var systemColorScheme
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var themeResolver = ThemeResolver.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsViewModel)
                .environmentObject(homeViewModel)
                .appTheme(themeResolver.colors)
                .preferredColorScheme(settingsViewModel.colorScheme)
                .onAppear {
                    themeResolver.apply(
                        themeId: settingsViewModel.settings.colorThemeId,
                        appearance: settingsViewModel.settings.appearance,
                        systemColorScheme: systemColorScheme
                    )
                }
                .onChange(of: settingsViewModel.settings) { _, settings in
                    themeResolver.apply(
                        themeId: settings.colorThemeId,
                        appearance: settings.appearance,
                        systemColorScheme: systemColorScheme
                    )
                }
                .onChange(of: systemColorScheme) { _, scheme in
                    themeResolver.apply(
                        themeId: settingsViewModel.settings.colorThemeId,
                        appearance: settingsViewModel.settings.appearance,
                        systemColorScheme: scheme
                    )
                }
        }
    }
}

