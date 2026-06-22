import SwiftUI

@MainActor
final class ThemeResolver: ObservableObject {
    static let shared = ThemeResolver()
    nonisolated static let defaultThemeId = "xuzhang_default"

    @Published private(set) var colors: ResolvedThemeTokens = .fallback

    private var cachedCatalog: ThemeCatalog?
    private var resolvedCache: [String: ResolvedThemeTokens] = [:]

    static var current: ResolvedThemeTokens {
        shared.colors
    }

    var catalog: ThemeCatalog {
        if let cachedCatalog {
            return cachedCatalog
        }
        let loaded = Self.loadCatalog()
        cachedCatalog = loaded
        return loaded
    }

    var themes: [ThemeDefinition] {
        catalog.themes
    }

    func apply(
        themeId: String,
        appearance: AppSettings.Appearance,
        systemColorScheme: ColorScheme = .light
    ) {
        colors = resolve(
            themeId: themeId,
            appearance: appearance,
            systemColorScheme: systemColorScheme
        )
    }

    func resolve(
        themeId: String,
        appearance: AppSettings.Appearance,
        systemColorScheme: ColorScheme = .light
    ) -> ResolvedThemeTokens {
        let mode = resolvedMode(appearance: appearance, systemColorScheme: systemColorScheme)
        let id = catalog.themeIDs.contains(themeId) ? themeId : Self.defaultThemeId
        let cacheKey = "\(id)#\(mode.rawValue)"
        if let cached = resolvedCache[cacheKey] {
            return cached
        }

        let definitionsById = Dictionary(uniqueKeysWithValues: catalog.themes.map { ($0.id, $0) })
        let definition = definitionsById[id] ?? definitionsById[Self.defaultThemeId]
        guard let definition else {
            return .fallback
        }
        let tokens = definition.modes[mode]
            ?? definition.modes[.light]
            ?? definitionsById[Self.defaultThemeId]?.modes[mode]
            ?? definitionsById[Self.defaultThemeId]?.modes[.light]
        guard let tokens else {
            return .fallback
        }

        let resolved = ResolvedThemeTokens(definition: definition, mode: mode, tokens: tokens)
        resolvedCache[cacheKey] = resolved
        return resolved
    }

    func definition(for id: String) -> ThemeDefinition? {
        catalog.themes.first { $0.id == id }
    }

    private func resolvedMode(
        appearance: AppSettings.Appearance,
        systemColorScheme: ColorScheme
    ) -> ThemeMode {
        switch appearance {
        case .system:
            return systemColorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private static func loadCatalog() -> ThemeCatalog {
        guard let url = Bundle.main.url(forResource: "ThemeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(ThemeCatalog.self, from: data) else {
            assertionFailure("ThemeCatalog.json is missing or invalid.")
            return ThemeCatalog(themes: [])
        }
        return catalog
    }
}
