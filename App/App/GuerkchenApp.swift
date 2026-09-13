import SwiftUI

@main
struct GuerkchenApp: App {
    @State private var appState = AppState()
    @State private var appearance = AppearanceSettings()

    var body: some Scene {
        Window("guerkchen", id: "main") {
            ContentView()
                .environment(appState)
                .environment(appearance)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            // Ersetzt den Standardeintrag, der nur eine fehlende Hilfe-Datei melden würde.
            CommandGroup(replacing: .help) {
                KeywordHelpMenuButton()
            }
            CommandGroup(replacing: .newItem) {
                Button("Neue Feature-Datei…") { appState.requestNewFile() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(appState.project == nil)
                Divider()
                Button("Ordner öffnen…") { appState.openFolderDialog() }
                    .keyboardShortcut("o", modifiers: .command)
                Menu("Zuletzt geöffnet") {
                    ForEach(appState.recent.urls, id: \.path) { url in
                        Button(url.lastPathComponent) { appState.open(url) }
                    }
                    if !appState.recent.urls.isEmpty {
                        Divider()
                        Button("Liste löschen") { appState.recent.clear() }
                    }
                }
                Button("Projekt schließen") { appState.closeProject() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(appState.project == nil)
            }
        }

        Window("Schlüsselwörter erklärt", id: KeywordHelpView.windowID) {
            KeywordHelpView()
                .environment(appState)
        }
        .defaultSize(width: 520, height: 640)

        Settings {
            SettingsView()
                .environment(appearance)
        }
    }
}
