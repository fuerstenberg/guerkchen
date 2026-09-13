import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppearanceSettings.self) private var appearance

    var body: some View {
        if let document = appState.document {
            VStack(spacing: 0) {
                if let loadError = document.loadError {
                    ContentUnavailableView("Datei kann nicht angezeigt werden", systemImage: "doc.badge.exclamationmark",
                                           description: Text(loadError))
                } else {
                    GherkinTextView(document: document, text: document.text, theme: appearance.theme) { code in
                        appState.project?.steps(for: code) ?? []
                    }
                }
                if let saveError = document.saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle")
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.2))
                }
            }
        } else {
            ContentUnavailableView {
                VStack(spacing: 12) {
                    Image("GuerkchenIcon")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text("Keine Datei ausgewählt")
                }
            } description: {
                Text("Wähle links eine .feature-Datei.")
            }
        }
    }
}
