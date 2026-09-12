import SwiftUI
import GuerkchenCore

struct FileTreeView: View {
    @Environment(AppState.self) private var appState

    private enum SheetKind: Identifiable {
        case newFile(in: URL)
        case newFolder(in: URL)
        case rename(URL, isDirectory: Bool)

        var id: String {
            switch self {
            case .newFile(let dir): return "newFile:\(dir.path)"
            case .newFolder(let dir): return "newFolder:\(dir.path)"
            case .rename(let url, _): return "rename:\(url.path)"
            }
        }
    }

    @State private var sheet: SheetKind?
    @State private var rootExpanded = true

    var body: some View {
        @Bindable var appState = appState
        List(selection: $appState.selectedFileURL) {
            if let project = appState.project {
                DisclosureGroup(isExpanded: $rootExpanded) {
                    OutlineGroup(project.tree.children ?? [], id: \.id, children: \.children) { node in
                        row(node)
                    }
                } label: {
                    Label(project.tree.name, systemImage: "folder.fill")
                        .contextMenu { directoryMenu(for: project.rootURL, isRoot: true) }
                }
                .selectionDisabled()
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appState.newFileRequestID) { _, _ in
            guard let project = appState.project else { return }
            sheet = .newFile(in: directoryForNewItems(project: project))
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .newFile(let dir):
                NameSheet(title: "Neue Feature-Datei", prompt: "Name (ohne .feature)", initialValue: "") { name in
                    perform { _ = try appState.project?.createFeatureFile(in: dir, name: name) }
                }
            case .newFolder(let dir):
                NameSheet(title: "Neuer Ordner", prompt: "Ordnername", initialValue: "") { name in
                    perform { _ = try appState.project?.createFolder(in: dir, name: name) }
                }
            case .rename(let url, _):
                NameSheet(title: "Umbenennen", prompt: "Neuer Name", initialValue: url.lastPathComponent) { name in
                    let wasSelected = appState.selectedFileURL == url
                    perform {
                        let renamed = try appState.project?.rename(url, to: name)
                        if wasSelected, let renamed { appState.select(renamed) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func row(_ node: FileNode) -> some View {
        if node.isDirectory {
            Label(node.name, systemImage: "folder")
                .selectionDisabled()
                .contextMenu { directoryMenu(for: node.url, isRoot: false) }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
                .contextMenu { fileMenu(for: node.url) }
        }
    }

    @ViewBuilder private func directoryMenu(for url: URL, isRoot: Bool) -> some View {
        Button("Neue Feature-Datei…") { sheet = .newFile(in: url) }
        Button("Neuer Ordner…") { sheet = .newFolder(in: url) }
        if !isRoot {
            Divider()
            Button("Umbenennen…") { sheet = .rename(url, isDirectory: true) }
            Button("In den Papierkorb legen") { trash(url) }
        }
    }

    @ViewBuilder private func fileMenu(for url: URL) -> some View {
        Button("Neue Feature-Datei…") { sheet = .newFile(in: url.deletingLastPathComponent()) }
        Button("Neuer Ordner…") { sheet = .newFolder(in: url.deletingLastPathComponent()) }
        Divider()
        Button("Umbenennen…") { sheet = .rename(url, isDirectory: false) }
        Button("In den Papierkorb legen") { trash(url) }
    }

    /// Cmd+N legt neben der ausgewählten Datei an, sonst im Projektordner.
    private func directoryForNewItems(project: ProjectFolder) -> URL {
        appState.selectedFileURL?.deletingLastPathComponent() ?? project.rootURL
    }

    private func trash(_ url: URL) {
        let affectsSelection = appState.selectedFileURL.map { $0.path.hasPrefix(url.path) } ?? false
        if affectsSelection { appState.select(nil) }
        perform { try appState.project?.trash(url) }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { appState.errorMessage = error.localizedDescription }
    }
}
