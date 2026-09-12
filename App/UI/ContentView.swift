import SwiftUI
import GuerkchenCore

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            detail
        }
        .navigationTitle(appState.project?.rootURL.lastPathComponent ?? "guerkchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.openFolderDialog()
                } label: {
                    Label("Ordner öffnen", systemImage: "folder")
                }
            }
        }
        .alert("Fehler", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    @ViewBuilder private var sidebar: some View {
        if let project = appState.project {
            // Platzhalter, wird in Task 12 durch FileTreeView ersetzt
            List(project.tree.children ?? [], id: \.id) { node in
                Label(node.name, systemImage: node.isDirectory ? "folder" : "doc.text")
            }
        } else {
            ContentUnavailableView {
                Label("Kein Projekt", systemImage: "folder.badge.questionmark")
            } description: {
                Text("Öffne einen Ordner mit .feature-Dateien.")
            } actions: {
                Button("Ordner öffnen…") { appState.openFolderDialog() }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        // Platzhalter, wird in Task 11 durch EditorView ersetzt
        ContentUnavailableView("Keine Datei ausgewählt", systemImage: "doc.text",
                               description: Text("Wähle links eine .feature-Datei."))
    }
}
