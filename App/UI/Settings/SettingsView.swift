import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppearanceSettings.self) private var appearance
    /// Die Schriftliste zeigt normalerweise nur Monospace-Familien – für einen Editor die
    /// sinnvolle Auswahl, aber nicht jeder will sich darauf festlegen lassen.
    @AppStorage("fontPickerShowsAllFonts") private var showsAllFonts = false

    var body: some View {
        Form {
            Section("Schrift") {
                Picker("Schriftart", selection: appearance.fontFamilyBinding) {
                    Text("Systemschrift (Monospace)").tag(String?.none)
                    Divider()
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(String?.some(family))
                    }
                }
                Toggle("Alle Schriften anzeigen", isOn: $showsAllFonts)
                Stepper("Schriftgröße: \(Int(appearance.theme.fontSize)) pt",
                        value: appearance.fontSizeBinding,
                        in: AppearanceSettings.fontSizeRange,
                        step: 1)
            }

            Section("Hintergrund") {
                Toggle("Systemhintergrund verwenden", isOn: appearance.usesSystemBackgroundBinding)
                ColorPicker("Hintergrundfarbe", selection: appearance.backgroundBinding, supportsOpacity: false)
                    .disabled(appearance.usesSystemBackground)
            }

            Section("Farben der Schlüsselwörter") {
                ForEach(HighlightCategory.allCases) { category in
                    ColorPicker(category.title, selection: appearance.binding(for: category), supportsOpacity: false)
                }
            }

            Section("Vorschau") {
                preview
            }

            Section {
                Button("Auf Standardfarben zurücksetzen") { appearance.resetColors() }
                Button("Schrift und Hintergrund zurücksetzen") { appearance.resetFontAndBackground() }
            }
        }
        .formStyle(.grouped)
        // Feste Größe: die Liste ist zu lang geworden, um das Fenster mitwachsen zu lassen.
        .frame(width: 440, height: 560)
    }

    private var preview: some View {
        let theme = appearance.theme
        return VStack(alignment: .leading, spacing: 2) {
            Text("Szenario: Anmeldung")
                .foregroundStyle(Color(nsColor: theme.color(for: .scenario)))
            Text("  Angenommen ein Benutzer ist angemeldet")
                .foregroundStyle(Color(nsColor: theme.color(for: .step)))
            Text("  # ein Kommentar")
                .foregroundStyle(Color(nsColor: theme.color(for: .comment)))
        }
        .font(Font(theme.font))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: theme.backgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
    }

    private var fontFamilies: [String] {
        var families = showsAllFonts ? FontCatalog.allFamilies : FontCatalog.monospacedFamilies
        // Eine zuvor gewählte Proportionalschrift darf nicht aus der Liste fallen,
        // sonst stünde der Picker leer da.
        if let current = appearance.theme.fontFamily, !families.contains(current) {
            families.append(current)
            families.sort()
        }
        return families
    }
}
