import AppKit

/// Alles, was das Aussehen des Editors bestimmt – als reiner Wert, damit sich billig
/// vergleichen lässt, ob neu gezeichnet werden muss.
struct EditorTheme: Equatable {
    var palette: HighlightPalette
    /// `nil` = Systemhintergrund, der Hell und Dunkel selbst folgt.
    var backgroundHex: String?
    /// `nil` = Systemschrift (Monospace).
    var fontFamily: String?
    var fontSize: Double

    var font: NSFont {
        let size = CGFloat(fontSize)
        // Gewicht 5 ist der reguläre Schnitt der Familie; fehlt die Schrift (deinstalliert,
        // Projekt auf einem anderen Rechner geöffnet), bleibt es bei der Systemschrift.
        guard let fontFamily,
              let resolved = NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: size)
        else { return NSFont.monospacedSystemFont(ofSize: size, weight: .regular) }
        return resolved
    }

    /// Die gewählte Hintergrundfarbe, oder `nil`, solange der Systemhintergrund gilt.
    var customBackgroundColor: NSColor? {
        guard let backgroundHex else { return nil }
        return NSColor(hex: backgroundHex)
    }

    var backgroundColor: NSColor {
        customBackgroundColor ?? .textBackgroundColor
    }

    /// `.textColor` folgt dem System-Erscheinungsbild und wäre auf einem eigenen Hintergrund
    /// schnell unlesbar – deshalb Schwarz oder Weiß passend zu dessen Helligkeit.
    var textColor: NSColor {
        guard let custom = customBackgroundColor else { return .textColor }
        return custom.isDark ? .white : .black
    }

    func color(for category: HighlightCategory) -> NSColor {
        NSColor(hex: palette[category] ?? category.defaultHex) ?? textColor
    }
}
