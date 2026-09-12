import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(ColorSettings.self) private var colors

    var body: some View {
        if let document = appState.document {
            VStack(spacing: 0) {
                if let loadError = document.loadError {
                    ContentUnavailableView("Datei kann nicht angezeigt werden", systemImage: "doc.badge.exclamationmark",
                                           description: Text(loadError))
                } else {
                    GherkinTextView(document: document, palette: colors.palette) { code in
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
            ContentUnavailableView("Keine Datei ausgewählt", systemImage: "doc.text",
                                   description: Text("Wähle links eine .feature-Datei."))
        }
    }
}
