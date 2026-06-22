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
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(TraceColors.surfaceGlass)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(TraceColors.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color(red: 0.561, green: 0.659, blue: 0.604).opacity(0.06), radius: 14, x: 0, y: 4)
    }

    func traceWarmPanel(radius: CGFloat = 26, padding: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TraceColors.surfaceWarm,
                                Color.white.opacity(0.76),
                                AppColors.paperMist.opacity(0.44)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppColors.paperCrease.opacity(0.18))
                    .frame(width: 2)
                    .padding(.vertical, 20)
                    .padding(.leading, 14)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.paperBorder.opacity(0.18), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
