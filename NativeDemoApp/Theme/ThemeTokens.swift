import Foundation
import SwiftUI

enum ThemeTier: String, Codable, CaseIterable, Identifiable {
    case free
    case standard
    case lifetime

    var id: String { rawValue }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
}

struct ThemeCatalog: Decodable {
    let themes: [ThemeDefinition]

    var themeIDs: [String] {
        themes.map(\.id)
    }
}

struct ThemeDefinition: Decodable, Identifiable {
    let id: String
    let displayName: String
    let tier: ThemeTier
    let family: String
    let unlockTier: ThemeTier?
    let modes: ThemeModes
}

struct ThemeModes: Decodable {
    let light: ThemeTokens?
    let dark: ThemeTokens?

    subscript(mode: ThemeMode) -> ThemeTokens? {
        switch mode {
        case .light:
            return light
        case .dark:
            return dark
        }
    }
}

struct ThemeTokens: Codable {
    let background: TokenColor
    let backgroundGradientEnd: TokenColor
    let surface: TokenColor
    let surfaceOpacity: Double
    let surfaceWarm: TokenColor
    let surfaceMuted: TokenColor
    let stroke: TokenColor
    let textPrimary: TokenColor
    let textSecondary: TokenColor
    let textTertiary: TokenColor
    let accent: TokenColor
    let accentDark: TokenColor
    let lockGold: TokenColor
    let heroGradientPink: TokenColor
    let heroGradientTeal: TokenColor
    let categoryColors: [TokenColor]
    let panel: TokenColor
    let panelOpacity: Double
    let panelStrong: TokenColor
    let panelStrongOpacity: Double
    let line: TokenColor
    let lineOpacity: Double
    let paperWarm: TokenColor
    let paperMist: TokenColor
    let paperBorder: TokenColor
    let paperCrease: TokenColor
    let tabActiveBg: TokenColor
    let tabActiveBgOpacity: Double
    let tabInactiveBg: TokenColor
    let tabInactiveBgOpacity: Double
    let tabInactiveGlyph: TokenColor
    let tabInactiveGlyphOpacity: Double
    let floatingPetPanel: TokenColor
    let floatingPetPanelOpacity: Double
    let settingsIdentityPanel: TokenColor
    let settingsIdentityPanelOpacity: Double
    let settingsChapterPanel: TokenColor
    let settingsChapterPanelOpacity: Double
    let tracePlaybackButtonBg: TokenColor
    let tracePlaybackButtonBgOpacity: Double
    let traceAppendixBg: TokenColor
    let traceAppendixBgOpacity: Double
    let monthlyInsightBg: TokenColor
    let monthlyInsightBgOpacity: Double
    let settingsEnvelopeIvory: TokenColor
    let settingsEnvelopeWarm: TokenColor
    let settingsEnvelopeMint: TokenColor
    let settingsEnvelopeSage: TokenColor
    let settingsEnvelopeDeepSage: TokenColor

    enum CodingKeys: String, CodingKey {
        case background, backgroundGradientEnd, surface, surfaceOpacity, surfaceWarm, surfaceMuted, stroke
        case textPrimary, textSecondary, textTertiary, accent, accentDark, lockGold, heroGradientPink, heroGradientTeal
        case categoryColors
        case panel, panelOpacity, panelStrong, panelStrongOpacity, line, lineOpacity
        case paperWarm, paperMist, paperBorder, paperCrease
        case tabActiveBg, tabActiveBgOpacity, tabInactiveBg, tabInactiveBgOpacity, tabInactiveGlyph, tabInactiveGlyphOpacity
        case floatingPetPanel, floatingPetPanelOpacity
        case settingsIdentityPanel, settingsIdentityPanelOpacity, settingsChapterPanel, settingsChapterPanelOpacity
        case tracePlaybackButtonBg, tracePlaybackButtonBgOpacity, traceAppendixBg, traceAppendixBgOpacity
        case monthlyInsightBg, monthlyInsightBgOpacity
        case settingsEnvelopeIvory, settingsEnvelopeWarm, settingsEnvelopeMint, settingsEnvelopeSage, settingsEnvelopeDeepSage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decode(TokenColor.self, forKey: .background)
        backgroundGradientEnd = try container.decodeIfPresent(TokenColor.self, forKey: .backgroundGradientEnd) ?? background
        surface = try container.decodeIfPresent(TokenColor.self, forKey: .surface) ?? TokenColor("#FFFFFF")
        surfaceOpacity = try container.decodeIfPresent(Double.self, forKey: .surfaceOpacity) ?? 0.72
        surfaceWarm = try container.decodeIfPresent(TokenColor.self, forKey: .surfaceWarm) ?? background
        surfaceMuted = try container.decodeIfPresent(TokenColor.self, forKey: .surfaceMuted) ?? surface
        stroke = try container.decodeIfPresent(TokenColor.self, forKey: .stroke) ?? surfaceMuted
        textPrimary = try container.decode(TokenColor.self, forKey: .textPrimary)
        textSecondary = try container.decode(TokenColor.self, forKey: .textSecondary)
        textTertiary = try container.decodeIfPresent(TokenColor.self, forKey: .textTertiary) ?? textSecondary
        accent = try container.decode(TokenColor.self, forKey: .accent)
        accentDark = try container.decodeIfPresent(TokenColor.self, forKey: .accentDark) ?? accent
        lockGold = try container.decodeIfPresent(TokenColor.self, forKey: .lockGold) ?? TokenColor("#C9A64A")
        heroGradientPink = try container.decodeIfPresent(TokenColor.self, forKey: .heroGradientPink) ?? accent
        heroGradientTeal = try container.decodeIfPresent(TokenColor.self, forKey: .heroGradientTeal) ?? accentDark
        categoryColors = try container.decode([TokenColor].self, forKey: .categoryColors)
        panel = try container.decodeIfPresent(TokenColor.self, forKey: .panel) ?? surface
        panelOpacity = try container.decodeIfPresent(Double.self, forKey: .panelOpacity) ?? 0.62
        panelStrong = try container.decodeIfPresent(TokenColor.self, forKey: .panelStrong) ?? surface
        panelStrongOpacity = try container.decodeIfPresent(Double.self, forKey: .panelStrongOpacity) ?? 0.82
        line = try container.decodeIfPresent(TokenColor.self, forKey: .line) ?? stroke
        lineOpacity = try container.decodeIfPresent(Double.self, forKey: .lineOpacity) ?? 0.52
        paperWarm = try container.decodeIfPresent(TokenColor.self, forKey: .paperWarm) ?? surfaceWarm
        paperMist = try container.decodeIfPresent(TokenColor.self, forKey: .paperMist) ?? surfaceMuted
        paperBorder = try container.decodeIfPresent(TokenColor.self, forKey: .paperBorder) ?? stroke
        paperCrease = try container.decodeIfPresent(TokenColor.self, forKey: .paperCrease) ?? accentDark
        tabActiveBg = try container.decodeIfPresent(TokenColor.self, forKey: .tabActiveBg) ?? accent
        tabActiveBgOpacity = try container.decodeIfPresent(Double.self, forKey: .tabActiveBgOpacity) ?? 0.42
        tabInactiveBg = try container.decodeIfPresent(TokenColor.self, forKey: .tabInactiveBg) ?? accent
        tabInactiveBgOpacity = try container.decodeIfPresent(Double.self, forKey: .tabInactiveBgOpacity) ?? 0.30
        tabInactiveGlyph = try container.decodeIfPresent(TokenColor.self, forKey: .tabInactiveGlyph) ?? textSecondary
        tabInactiveGlyphOpacity = try container.decodeIfPresent(Double.self, forKey: .tabInactiveGlyphOpacity) ?? 0.62
        floatingPetPanel = try container.decodeIfPresent(TokenColor.self, forKey: .floatingPetPanel) ?? tabInactiveBg
        floatingPetPanelOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingPetPanelOpacity) ?? 0.37
        settingsIdentityPanel = try container.decodeIfPresent(TokenColor.self, forKey: .settingsIdentityPanel) ?? surfaceWarm
        settingsIdentityPanelOpacity = try container.decodeIfPresent(Double.self, forKey: .settingsIdentityPanelOpacity) ?? 0.54
        settingsChapterPanel = try container.decodeIfPresent(TokenColor.self, forKey: .settingsChapterPanel) ?? surfaceWarm
        settingsChapterPanelOpacity = try container.decodeIfPresent(Double.self, forKey: .settingsChapterPanelOpacity) ?? 0.50
        tracePlaybackButtonBg = try container.decodeIfPresent(TokenColor.self, forKey: .tracePlaybackButtonBg) ?? accent
        tracePlaybackButtonBgOpacity = try container.decodeIfPresent(Double.self, forKey: .tracePlaybackButtonBgOpacity) ?? 0.25
        traceAppendixBg = try container.decodeIfPresent(TokenColor.self, forKey: .traceAppendixBg) ?? accent
        traceAppendixBgOpacity = try container.decodeIfPresent(Double.self, forKey: .traceAppendixBgOpacity) ?? 0.19
        monthlyInsightBg = try container.decodeIfPresent(TokenColor.self, forKey: .monthlyInsightBg) ?? surfaceWarm
        monthlyInsightBgOpacity = try container.decodeIfPresent(Double.self, forKey: .monthlyInsightBgOpacity) ?? 0.62
        settingsEnvelopeIvory = try container.decodeIfPresent(TokenColor.self, forKey: .settingsEnvelopeIvory) ?? surfaceWarm
        settingsEnvelopeWarm = try container.decodeIfPresent(TokenColor.self, forKey: .settingsEnvelopeWarm) ?? paperBorder
        settingsEnvelopeMint = try container.decodeIfPresent(TokenColor.self, forKey: .settingsEnvelopeMint) ?? paperMist
        settingsEnvelopeSage = try container.decodeIfPresent(TokenColor.self, forKey: .settingsEnvelopeSage) ?? accent
        settingsEnvelopeDeepSage = try container.decodeIfPresent(TokenColor.self, forKey: .settingsEnvelopeDeepSage) ?? accentDark
    }
}

struct TokenColor: Codable, Hashable {
    let hex: String

    init(_ hex: String) {
        self.hex = hex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        hex = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

struct ResolvedThemeTokens {
    let id: String
    let displayName: String
    let tier: ThemeTier
    let family: String
    let mode: ThemeMode
    let background: Color
    let backgroundGradientEnd: Color
    let surface: Color
    let surfaceWarm: Color
    let surfaceMuted: Color
    let stroke: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let accentDark: Color
    let readableAccent: Color
    let onAccent: Color
    let lockGold: Color
    let heroGradientPink: Color
    let heroGradientTeal: Color
    let categoryColors: [Color]
    let panel: Color
    let panelStrong: Color
    let line: Color
    let paperWarm: Color
    let paperMist: Color
    let paperBorder: Color
    let paperCrease: Color
    let tabActiveBg: Color
    let tabInactiveBg: Color
    let tabInactiveGlyph: Color
    let floatingPetPanel: Color
    let settingsIdentityPanel: Color
    let settingsChapterPanel: Color
    let tracePlaybackButtonBg: Color
    let traceAppendixBg: Color
    let monthlyInsightBg: Color
    let settingsEnvelopeIvory: Color
    let settingsEnvelopeWarm: Color
    let settingsEnvelopeMint: Color
    let settingsEnvelopeSage: Color
    let settingsEnvelopeDeepSage: Color

    init(definition: ThemeDefinition, mode: ThemeMode, tokens: ThemeTokens) {
        self.id = definition.id
        self.displayName = definition.displayName
        self.tier = definition.tier
        self.family = definition.family
        self.mode = mode
        background = tokens.background.color
        backgroundGradientEnd = tokens.backgroundGradientEnd.color
        surface = tokens.surface.color.opacity(tokens.surfaceOpacity)
        surfaceWarm = tokens.surfaceWarm.color
        surfaceMuted = tokens.surfaceMuted.color
        stroke = tokens.stroke.color
        textPrimary = tokens.textPrimary.color
        textSecondary = tokens.textSecondary.color
        textTertiary = tokens.textTertiary.color
        accent = tokens.accent.color
        accentDark = tokens.accentDark.color
        readableAccent = Self.readableAccentColor(
            accent: tokens.accent,
            accentDark: tokens.accentDark,
            textPrimary: tokens.textPrimary,
            backgrounds: [tokens.background, tokens.surface]
        )
        onAccent = Self.foregroundColor(on: tokens.accent, preferred: tokens.textPrimary)
        lockGold = tokens.lockGold.color
        heroGradientPink = tokens.heroGradientPink.color
        heroGradientTeal = tokens.heroGradientTeal.color
        categoryColors = tokens.categoryColors.map(\.color)
        panel = tokens.panel.color.opacity(tokens.panelOpacity)
        panelStrong = tokens.panelStrong.color.opacity(tokens.panelStrongOpacity)
        line = tokens.line.color.opacity(tokens.lineOpacity)
        paperWarm = tokens.paperWarm.color
        paperMist = tokens.paperMist.color
        paperBorder = tokens.paperBorder.color
        paperCrease = tokens.paperCrease.color
        tabActiveBg = tokens.tabActiveBg.color.opacity(tokens.tabActiveBgOpacity)
        tabInactiveBg = tokens.tabInactiveBg.color.opacity(tokens.tabInactiveBgOpacity)
        tabInactiveGlyph = tokens.tabInactiveGlyph.color.opacity(tokens.tabInactiveGlyphOpacity)
        floatingPetPanel = tokens.floatingPetPanel.color.opacity(tokens.floatingPetPanelOpacity)
        settingsIdentityPanel = tokens.settingsIdentityPanel.color.opacity(tokens.settingsIdentityPanelOpacity)
        settingsChapterPanel = tokens.settingsChapterPanel.color.opacity(tokens.settingsChapterPanelOpacity)
        tracePlaybackButtonBg = tokens.tracePlaybackButtonBg.color.opacity(tokens.tracePlaybackButtonBgOpacity)
        traceAppendixBg = tokens.traceAppendixBg.color.opacity(tokens.traceAppendixBgOpacity)
        monthlyInsightBg = tokens.monthlyInsightBg.color.opacity(tokens.monthlyInsightBgOpacity)
        settingsEnvelopeIvory = tokens.settingsEnvelopeIvory.color
        settingsEnvelopeWarm = tokens.settingsEnvelopeWarm.color
        settingsEnvelopeMint = tokens.settingsEnvelopeMint.color
        settingsEnvelopeSage = tokens.settingsEnvelopeSage.color
        settingsEnvelopeDeepSage = tokens.settingsEnvelopeDeepSage.color
    }

    static let fallback = ResolvedThemeTokens(
        id: ThemeResolver.defaultThemeId,
        displayName: "叙账默认",
        tier: .free,
        family: "default",
        mode: .light
    )

    private init(id: String, displayName: String, tier: ThemeTier, family: String, mode: ThemeMode) {
        self.id = id
        self.displayName = displayName
        self.tier = tier
        self.family = family
        self.mode = mode
        background = Color(red: 0.933, green: 0.941, blue: 0.957)
        backgroundGradientEnd = Color(red: 0.933, green: 0.941, blue: 0.957)
        surface = Color.white.opacity(0.72)
        surfaceWarm = Color(red: 1.0, green: 0.969, blue: 0.925)
        surfaceMuted = Color(red: 0.941, green: 0.949, blue: 0.961)
        stroke = Color(red: 0.910, green: 0.929, blue: 0.949)
        let fallbackTextPrimary = Color(red: 0.145, green: 0.188, blue: 0.255)
        textPrimary = fallbackTextPrimary
        textSecondary = Color(red: 0.365, green: 0.412, blue: 0.494)
        textTertiary = Color(red: 0.541, green: 0.584, blue: 0.659)
        accent = Color(red: 0.498, green: 0.702, blue: 0.635)
        accentDark = Color(red: 0.471, green: 0.682, blue: 0.620)
        readableAccent = fallbackTextPrimary
        onAccent = fallbackTextPrimary
        lockGold = Color(red: 0.788, green: 0.651, blue: 0.290)
        heroGradientPink = Color(red: 1.0, green: 0.773, blue: 0.871)
        heroGradientTeal = Color(red: 0.690, green: 0.878, blue: 0.859)
        categoryColors = [
            Color(hexString: "#6A9FA8"),
            Color(hexString: "#B8957A"),
            Color(hexString: "#8FA888"),
            Color(hexString: "#A892A8"),
            Color(hexString: "#7FA882"),
            Color(hexString: "#C4A67A"),
            Color(hexString: "#A89888"),
            Color(hexString: "#8A96AA")
        ]
        panel = Color.white.opacity(0.62)
        panelStrong = Color.white.opacity(0.82)
        line = Color.white.opacity(0.52)
        paperWarm = Color(red: 0.992, green: 0.952, blue: 0.878)
        paperMist = Color(red: 0.938, green: 0.958, blue: 0.932)
        paperBorder = Color(red: 0.902, green: 0.760, blue: 0.584)
        paperCrease = Color(red: 0.760, green: 0.560, blue: 0.360)
        tabActiveBg = Color(red: 0.67, green: 0.87, blue: 0.75).opacity(0.42)
        tabInactiveBg = Color(red: 0.749, green: 0.851, blue: 0.817).opacity(0.30)
        tabInactiveGlyph = Color(red: 0.467, green: 0.592, blue: 0.598).opacity(0.62)
        floatingPetPanel = Color(red: 0.749, green: 0.851, blue: 0.817).opacity(0.37)
        settingsIdentityPanel = Color(red: 0.988, green: 0.964, blue: 0.920).opacity(0.54)
        settingsChapterPanel = Color(red: 0.972, green: 0.962, blue: 0.944).opacity(0.50)
        tracePlaybackButtonBg = Color(red: 0.774, green: 0.866, blue: 0.836).opacity(0.25)
        traceAppendixBg = Color(red: 0.749, green: 0.851, blue: 0.817).opacity(0.19)
        monthlyInsightBg = Color(red: 1.0, green: 0.979, blue: 0.944).opacity(0.62)
        settingsEnvelopeIvory = Color(hexString: "#F8F3E8")
        settingsEnvelopeWarm = Color(hexString: "#F1D8B6")
        settingsEnvelopeMint = Color(hexString: "#CDE1D8")
        settingsEnvelopeSage = Color(hexString: "#8FB1A3")
        settingsEnvelopeDeepSage = Color(hexString: "#4D776A")
    }

    private static func readableAccentColor(
        accent: TokenColor,
        accentDark: TokenColor,
        textPrimary: TokenColor,
        backgrounds: [TokenColor]
    ) -> Color {
        let candidates = [accentDark, accent, textPrimary]
        if let accessible = candidates.first(where: { candidate in
            backgrounds.allSatisfy { candidate.contrastRatio(to: $0) >= 4.5 }
        }) {
            return accessible.color
        }
        return candidates.max { lhs, rhs in
            lhs.minimumContrast(against: backgrounds) < rhs.minimumContrast(against: backgrounds)
        }?.color ?? textPrimary.color
    }

    private static func foregroundColor(on background: TokenColor, preferred: TokenColor) -> Color {
        if preferred.contrastRatio(to: background) >= 4.5 {
            return preferred.color
        }
        let candidates = [preferred, TokenColor("#000000"), TokenColor("#FFFFFF")]
        return candidates.max {
            $0.contrastRatio(to: background) < $1.contrastRatio(to: background)
        }?.color ?? preferred.color
    }
}

extension TokenColor {
    var color: Color {
        Color(hexString: hex)
    }

    fileprivate func contrastRatio(to other: TokenColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    fileprivate func minimumContrast(against backgrounds: [TokenColor]) -> Double {
        backgrounds.map { contrastRatio(to: $0) }.min() ?? 0
    }

    private var relativeLuminance: Double {
        let components = rgbComponents
        return 0.2126 * Self.linearized(components.red)
            + 0.7152 * Self.linearized(components.green)
            + 0.0722 * Self.linearized(components.blue)
    }

    private var rgbComponents: (red: Double, green: Double, blue: Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return (
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    private static func linearized(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

private extension Color {
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
