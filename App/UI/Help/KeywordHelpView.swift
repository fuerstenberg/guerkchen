import SwiftUI
import GuerkchenCore

/// Nachschlagefenster: jedes Schlüsselwort in einem Satz erklärt, dazu ein kurzes Beispiel.
/// Gedacht für alle, die Anforderungen schreiben, ohne Gherkin gelernt zu haben.
struct KeywordHelpView: View {
    static let windowID = "keyword-help"

    @Environment(AppState.self) private var appState

    var body: some View {
        // Die Beispiele sollen so aussehen wie die Datei, die gerade offen ist.
        let dialect = appState.dialect
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(for: dialect)
                ForEach(KeywordHelp.all(for: dialect)) { entry in
                    Divider()
                    row(entry)
                }
                Divider()
                footer
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 420, minHeight: 400)
    }

    private func header(for dialect: GherkinDialect) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Eine .feature-Datei beschreibt, was eine Software können soll – in festen Worten, "
                 + "damit alle dasselbe darunter verstehen. Diese Worte stehen hier, von oben nach "
                 + "unten in der Reihenfolge, in der sie in der Datei vorkommen.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Beispiele in der Sprache der geöffneten Datei: \(dialect.native)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func row(_ entry: KeywordHelp) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.keyword)
                    .font(.headline)
                if !entry.alternatives.isEmpty {
                    Text("gleichbedeutend: \(entry.alternatives.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(entry.summary)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.example)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
        }
        .padding(.vertical, 12)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gut zu wissen")
                .font(.headline)
            Text("Zeilen, die mit # beginnen, sind Notizen und werden überlesen. Mit @ beginnen "
                 + "Schlagworte, nach denen man Dateien später filtern kann. Die Sprache legt die "
                 + "erste Zeile der Datei fest, zum Beispiel „# language: de“ – ohne sie gilt Englisch.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }
}

/// Eigener View, damit `openWindow` aus dem Environment kommt – im `App`-Typ gibt es das nicht.
struct KeywordHelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Schlüsselwörter erklärt") { openWindow(id: KeywordHelpView.windowID) }
            .keyboardShortcut("?", modifiers: .command)
    }
}
