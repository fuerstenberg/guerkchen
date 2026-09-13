import AppKit

/// Die Schriftfamilien für die Auswahl in den Einstellungen. Die Abfrage beim NSFontManager
/// ist teuer genug, um sie nur einmal zu machen.
enum FontCatalog {
    static let monospacedFamilies: [String] = {
        let names = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
        var families = Set<String>()
        for name in names {
            if let family = NSFont(name: name, size: 12)?.familyName { families.insert(family) }
        }
        return families.sorted()
    }()

    static let allFamilies: [String] = NSFontManager.shared.availableFontFamilies.sorted()
}
