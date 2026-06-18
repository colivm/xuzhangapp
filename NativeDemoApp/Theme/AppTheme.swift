import SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: ResolvedThemeTokens = .fallback
}

extension EnvironmentValues {
    var appTheme: ResolvedThemeTokens {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    func appTheme(_ theme: ResolvedThemeTokens) -> some View {
        environment(\.appTheme, theme)
    }
}
