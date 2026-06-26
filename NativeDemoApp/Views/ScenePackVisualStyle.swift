import SwiftUI

struct ScenePackVisualStyle {
    let colors: [Color]
    let symbols: [String]
    let keyword: String
}

struct ScenePackVisualBackdrop: View {
    let style: ScenePackVisualStyle
    var compact = false
    var isSubtle = false

    private var primaryColor: Color {
        style.colors.first ?? AppColors.accent
    }

    private var secondaryColor: Color {
        style.colors.dropFirst().first ?? AppColors.heroGradientTeal
    }

    private var themeColor: Color {
        style.colors.dropFirst(2).first ?? AppColors.accent
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.surfaceMuted.opacity(isSubtle ? 0.20 : 0.34),
                    primaryColor.opacity(isSubtle ? 0.24 : 0.76),
                    secondaryColor.opacity(isSubtle ? 0.18 : 0.70),
                    themeColor.opacity(isSubtle ? 0.10 : 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(isSubtle ? 0.18 : 0.30),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: compact ? 92 : 150
            )

            sceneLineTexture

            ForEach(Array(style.symbols.prefix(2).enumerated()), id: \.offset) { index, symbol in
                GeometryReader { proxy in
                    Image(systemName: symbol)
                        .font(.system(size: symbolSize(index), weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.white.opacity(symbolOpacity(index)))
                        .rotationEffect(.degrees(index == 0 ? -8 : 12))
                        .position(
                            x: proxy.size.width * (index == 0 ? 0.72 : 0.90),
                            y: proxy.size.height * (index == 0 ? 0.38 : 0.68)
                        )
                }
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(isSubtle ? 0.12 : 0.20),
                    Color.clear,
                    themeColor.opacity(isSubtle ? 0.05 : 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(isSubtle ? 0.08 : 0.15),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: compact ? 36 : 58)
            .rotationEffect(.degrees(18))
            .offset(x: compact ? 22 : 48)
        }
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 15 : 16, style: .continuous)
                .stroke(Color.white.opacity(isSubtle ? 0.12 : 0.20), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private var sceneLineTexture: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.68))
            route.addCurve(
                to: CGPoint(x: size.width * 0.94, y: size.height * 0.30),
                control1: CGPoint(x: size.width * 0.32, y: size.height * 0.30),
                control2: CGPoint(x: size.width * 0.62, y: size.height * 0.88)
            )
            context.stroke(
                route,
                with: .color(Color.white.opacity(isSubtle ? 0.12 : 0.22)),
                style: StrokeStyle(lineWidth: compact ? 1.2 : 1.7, lineCap: .round)
            )

            for point in [
                CGPoint(x: size.width * 0.20, y: size.height * 0.46),
                CGPoint(x: size.width * 0.52, y: size.height * 0.58),
                CGPoint(x: size.width * 0.78, y: size.height * 0.38)
            ] {
                let rect = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(isSubtle ? 0.14 : 0.26)))
            }
        }
        .blendMode(.screen)
    }

    private func symbolSize(_ index: Int) -> CGFloat {
        if compact {
            return index == 0 ? 30 : 40
        }
        return index == 0 ? 48 : 64
    }

    private func symbolOpacity(_ index: Int) -> Double {
        if isSubtle {
            return index == 0 ? 0.13 : 0.08
        }
        return index == 0 ? 0.30 : 0.18
    }
}

@MainActor
enum ScenePackVisualStyles {
    static func style(for packId: String) -> ScenePackVisualStyle {
        switch packId {
        case "commute":
            return themedStyle(colors: [Color(red: 0.24, green: 0.50, blue: 0.86), Color(red: 0.42, green: 0.78, blue: 0.74)], symbols: ["tram.fill", "car.fill"], keyword: "出门")
        case "food":
            return themedStyle(colors: [Color(red: 0.95, green: 0.43, blue: 0.35), Color(red: 0.98, green: 0.72, blue: 0.38)], symbols: ["cup.and.saucer.fill", "fork.knife"], keyword: "干饭")
        case "supply":
            return themedStyle(colors: [Color(red: 0.30, green: 0.63, blue: 0.48), Color(red: 0.79, green: 0.74, blue: 0.42)], symbols: ["basket.fill", "shippingbox.fill"], keyword: "补货")
        case "shopping":
            return themedStyle(colors: [Color(red: 0.58, green: 0.45, blue: 0.86), Color(red: 0.94, green: 0.54, blue: 0.68)], symbols: ["bag.fill", "camera.fill"], keyword: "快递")
        case "care":
            return themedStyle(colors: [Color(red: 0.22, green: 0.64, blue: 0.66), Color(red: 0.60, green: 0.74, blue: 0.88)], symbols: ["heart.fill", "figure.strengthtraining.traditional"], keyword: "身体")
        case "home":
            return themedStyle(colors: [Color(red: 0.58, green: 0.54, blue: 0.46), Color(red: 0.77, green: 0.64, blue: 0.47)], symbols: ["house.fill", "wrench.and.screwdriver.fill"], keyword: "住处")
        case "social":
            return themedStyle(colors: [Color(red: 0.88, green: 0.35, blue: 0.48), Color(red: 0.93, green: 0.68, blue: 0.36)], symbols: ["gift.fill", "person.2.fill"], keyword: "人情")
        case "travel":
            return themedStyle(colors: [Color(red: 0.24, green: 0.47, blue: 0.82), Color(red: 0.62, green: 0.74, blue: 0.50)], symbols: ["airplane", "map.fill"], keyword: "出走")
        case "family":
            return themedStyle(colors: [Color(red: 0.94, green: 0.52, blue: 0.55), Color(red: 0.62, green: 0.57, blue: 0.86)], symbols: ["pawprint.fill", "figure.and.child.holdinghands"], keyword: "照护")
        default:
            return themedStyle(colors: [AppColors.accent, AppColors.heroGradientTeal], symbols: ["sparkles"], keyword: "生活")
        }
    }

    static func style(for pack: ScenePackDefinition) -> ScenePackVisualStyle {
        style(for: pack.id)
    }

    private static func themedStyle(
        colors: [Color],
        symbols: [String],
        keyword: String
    ) -> ScenePackVisualStyle {
        ScenePackVisualStyle(
            colors: colors + [AppColors.accent, AppColors.heroGradientTeal],
            symbols: symbols,
            keyword: keyword
        )
    }
}
