import AppKit
import Observation
import SwiftUI

typealias HighlightPalette = [HighlightCategory: String]

@MainActor
@Observable
final class ColorSettings {
    private static let keyPrefix = "highlightColor."

    private(set) var palette: HighlightPalette = [:]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func color(for category: HighlightCategory) -> NSColor {
        NSColor(hex: palette[category] ?? category.defaultHex) ?? .textColor
    }

    func setColor(_ color: NSColor, for category: HighlightCategory) {
        let hex = color.hexString
        palette[category] = hex
        defaults.set(hex, forKey: Self.keyPrefix + category.rawValue)
    }

    func reset() {
        for category in HighlightCategory.allCases {
            defaults.removeObject(forKey: Self.keyPrefix + category.rawValue)
        }
        load()
    }

    func binding(for category: HighlightCategory) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: self.color(for: category)) },
            set: { self.setColor(NSColor($0), for: category) })
    }

    private func load() {
        var result: HighlightPalette = [:]
        for category in HighlightCategory.allCases {
            if let stored = defaults.string(forKey: Self.keyPrefix + category.rawValue), NSColor(hex: stored) != nil {
                result[category] = stored
            } else {
                result[category] = category.defaultHex
            }
        }
        palette = result
    }
}
