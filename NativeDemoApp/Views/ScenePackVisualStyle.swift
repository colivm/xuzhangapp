import SwiftUI

struct ScenePackVisualStyle {
    let colors: [Color]
    let symbols: [String]
    let keyword: String
}

@MainActor
enum ScenePackVisualStyles {
    static func style(for packId: String) -> ScenePackVisualStyle {
        switch packId {
        case "commute":
            return ScenePackVisualStyle(colors: [Color(red: 0.24, green: 0.50, blue: 0.86), Color(red: 0.42, green: 0.78, blue: 0.74)], symbols: ["tram.fill", "car.fill"], keyword: "出门")
        case "food":
            return ScenePackVisualStyle(colors: [Color(red: 0.95, green: 0.43, blue: 0.35), Color(red: 0.98, green: 0.72, blue: 0.38)], symbols: ["cup.and.saucer.fill", "fork.knife"], keyword: "干饭")
        case "supply":
            return ScenePackVisualStyle(colors: [Color(red: 0.30, green: 0.63, blue: 0.48), Color(red: 0.79, green: 0.74, blue: 0.42)], symbols: ["basket.fill", "shippingbox.fill"], keyword: "补货")
        case "shopping":
            return ScenePackVisualStyle(colors: [Color(red: 0.58, green: 0.45, blue: 0.86), Color(red: 0.94, green: 0.54, blue: 0.68)], symbols: ["bag.fill", "camera.fill"], keyword: "快递")
        case "care":
            return ScenePackVisualStyle(colors: [Color(red: 0.22, green: 0.64, blue: 0.66), Color(red: 0.60, green: 0.74, blue: 0.88)], symbols: ["heart.fill", "figure.strengthtraining.traditional"], keyword: "身体")
        case "home":
            return ScenePackVisualStyle(colors: [Color(red: 0.58, green: 0.54, blue: 0.46), Color(red: 0.77, green: 0.64, blue: 0.47)], symbols: ["house.fill", "wrench.and.screwdriver.fill"], keyword: "住处")
        case "social":
            return ScenePackVisualStyle(colors: [Color(red: 0.88, green: 0.35, blue: 0.48), Color(red: 0.93, green: 0.68, blue: 0.36)], symbols: ["gift.fill", "person.2.fill"], keyword: "人情")
        case "travel":
            return ScenePackVisualStyle(colors: [Color(red: 0.24, green: 0.47, blue: 0.82), Color(red: 0.62, green: 0.74, blue: 0.50)], symbols: ["airplane", "map.fill"], keyword: "出走")
        case "family":
            return ScenePackVisualStyle(colors: [Color(red: 0.94, green: 0.52, blue: 0.55), Color(red: 0.62, green: 0.57, blue: 0.86)], symbols: ["pawprint.fill", "figure.and.child.holdinghands"], keyword: "照护")
        default:
            return ScenePackVisualStyle(colors: [AppColors.accent, AppColors.heroGradientTeal], symbols: ["sparkles"], keyword: "生活")
        }
    }

    static func style(for pack: ScenePackDefinition) -> ScenePackVisualStyle {
        style(for: pack.id)
    }
}
