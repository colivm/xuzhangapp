import SwiftUI

@MainActor
enum TraceColors {
    static var primaryText: Color { AppColors.text }
    static var secondaryText: Color { AppColors.subtext }
    static var tertiaryText: Color { AppColors.tertiary }
    static var surfaceWarm: Color { AppColors.paperWarm }
    static var surfaceGlass: Color { AppColors.panel }
    static var surfaceMuted: Color { AppColors.surfaceMuted }
    static var stroke: Color { AppColors.stroke }
}

extension View {
    func traceGlassPanel(radius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        self
            .appSurface(.trace, radius: radius, padding: padding, tint: AppColors.accent)
    }

    func traceWarmPanel(radius: CGFloat = 26, padding: CGFloat = 24) -> some View {
        self
            .appSurface(.playback, radius: radius, padding: padding, tint: AppColors.accentDark)
    }
}
