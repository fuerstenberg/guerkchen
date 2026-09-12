import SwiftUI

struct SettingsView: View {
    @Environment(ColorSettings.self) private var colors

    var body: some View {
        Form {
            Section("Farben der Schlüsselwörter") {
                ForEach(HighlightCategory.allCases) { category in
                    ColorPicker(category.title, selection: colors.binding(for: category), supportsOpacity: false)
                }
            }
            Section {
                Button("Auf Standardfarben zurücksetzen") { colors.reset() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.bottom)
        .fixedSize(horizontal: false, vertical: true)
    }
}
