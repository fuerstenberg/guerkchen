import AppKit
import Observation
import SwiftUI

typealias HighlightPalette = [HighlightCategory: String]

@MainActor
@Observable
final class AppearanceSettings {
    private static let colorKeyPrefix = "highlightColor."
    private static let backgroundKey = "editorBackgroundColor"
    private static let fontFamilyKey = "editorFontFamily"
    private static let fontSizeKey = "editorFontSize"

    static let defaultFontSize: Double = 13
    static let fontSizeRange: ClosedRange<Double> = 9...32

    private(set) var theme = EditorTheme(palette: [:], backgroundHex: nil, fontFamily: nil,
                                         fontSize: AppearanceSettings.defaultFontSize)
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Farben

    func color(for category: HighlightCategory) -> NSColor {
        theme.color(for: category)
    }

    func setColor(_ color: NSColor, for category: HighlightCategory) {
        let hex = color.hexString
        theme.palette[category] = hex
        defaults.set(hex, forKey: Self.colorKeyPrefix + category.rawValue)
    }

    func binding(for category: HighlightCategory) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: self.color(for: category)) },
            set: { self.setColor(NSColor($0), for: category) })
    }

    func resetColors() {
        for category in HighlightCategory.allCases {
            defaults.removeObject(forKey: Self.colorKeyPrefix + category.rawValue)
        }
        load()
    }

    // MARK: - Hintergrund

    var usesSystemBackground: Bool { theme.backgroundHex == nil }

    func setBackgroundHex(_ hex: String?) {
        theme.backgroundHex = hex
        if let hex {
            defaults.set(hex, forKey: Self.backgroundKey)
        } else {
            defaults.removeObject(forKey: Self.backgroundKey)
        }
    }

    var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: self.theme.backgroundColor) },
            set: { self.setBackgroundHex(NSColor($0).hexString) })
    }

    var usesSystemBackgroundBinding: Binding<Bool> {
        Binding(
            get: { self.usesSystemBackground },
            // Beim Wechsel auf eine eigene Farbe mit dem aktuellen Systemhintergrund starten,
            // damit der Editor nicht plötzlich anders aussieht.
            set: { self.setBackgroundHex($0 ? nil : Self.systemBackgroundHex()) })
    }

    // MARK: - Schrift

    func setFontFamily(_ family: String?) {
        theme.fontFamily = family
        if let family {
            defaults.set(family, forKey: Self.fontFamilyKey)
        } else {
            defaults.removeObject(forKey: Self.fontFamilyKey)
        }
    }

    func setFontSize(_ size: Double) {
        let clamped = min(max(size.rounded(), Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        theme.fontSize = clamped
        defaults.set(clamped, forKey: Self.fontSizeKey)
    }

    var fontFamilyBinding: Binding<String?> {
        Binding(
            get: { self.theme.fontFamily },
            set: { self.setFontFamily($0) })
    }

    var fontSizeBinding: Binding<Double> {
        Binding(
            get: { self.theme.fontSize },
            set: { self.setFontSize($0) })
    }

    func resetFontAndBackground() {
        defaults.removeObject(forKey: Self.fontFamilyKey)
        defaults.removeObject(forKey: Self.fontSizeKey)
        defaults.removeObject(forKey: Self.backgroundKey)
        load()
    }

    // MARK: - Private

    private func load() {
        var palette: HighlightPalette = [:]
        for category in HighlightCategory.allCases {
            if let stored = defaults.string(forKey: Self.colorKeyPrefix + category.rawValue), NSColor(hex: stored) != nil {
                palette[category] = stored
            } else {
                palette[category] = category.defaultHex
            }
        }

        var backgroundHex: String?
        if let stored = defaults.string(forKey: Self.backgroundKey), NSColor(hex: stored) != nil {
            backgroundHex = stored
        }

        var fontFamily = defaults.string(forKey: Self.fontFamilyKey)
        if fontFamily?.isEmpty == true { fontFamily = nil }

        let storedSize = defaults.double(forKey: Self.fontSizeKey)
        let fontSize = Self.fontSizeRange.contains(storedSize) ? storedSize : Self.defaultFontSize

        theme = EditorTheme(palette: palette, backgroundHex: backgroundHex, fontFamily: fontFamily, fontSize: fontSize)
    }

    /// `NSColor.textBackgroundColor` ist eine dynamische Farbe – sie muss im aktuellen
    /// Erscheinungsbild aufgelöst werden, sonst käme im Dunkelmodus die helle Variante heraus.
    private static func systemBackgroundHex() -> String {
        var hex = "#FFFFFF"
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            if let resolved = NSColor.textBackgroundColor.usingColorSpace(.sRGB) { hex = resolved.hexString }
        }
        return hex
    }
}
