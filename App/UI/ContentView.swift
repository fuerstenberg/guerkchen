import SwiftUI
import GuerkchenCore

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            detail
        }
        .navigationTitle(appState.project?.rootURL.lastPathComponent ?? "guerkchen")
        .onChange(of: appState.selectedFileURL) { _, newValue in appState.select(newValue) }
        .onChange(of: appState.project?.changeCounter) { _, _ in appState.handleProjectChange() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.openFolderDialog()
                } label: {
                    Label("Ordner öffnen", systemImage: "folder")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: KeywordHelpView.windowID)
                } label: {
                    Label("Schlüsselwörter erklärt", systemImage: "questionmark.circle")
                }
                .help("Was bedeuten Feature, Szenario, Angenommen …?")
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
        if appState.project != nil {
            FileTreeView()
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
        EditorView()
    }
}
