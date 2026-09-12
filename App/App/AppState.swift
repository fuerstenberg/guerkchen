import AppKit
import Foundation
import Observation
import GuerkchenCore

@MainActor
@Observable
final class AppState {
    var project: ProjectFolder?
    var selectedFileURL: URL?
    var document: EditorDocument?
    var errorMessage: String?
    var newFileRequestID = 0
    let recent = RecentProjects()

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.document?.saveNow() }
        }
        if let last = recent.urls.first, FileManager.default.fileExists(atPath: last.path) {
            open(last)
        }
    }

    func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Projekt öffnen"
        panel.message = "Wähle einen Ordner mit .feature-Dateien."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.open(url) }
        }
    }

    func open(_ url: URL) {
        document?.saveNow()
        do {
            project = try ProjectFolder(rootURL: url)
            selectedFileURL = nil
            document = nil
            recent.add(url)
        } catch {
            errorMessage = "Der Ordner „\(url.lastPathComponent)“ konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    func closeProject() {
        document?.saveNow()
        project = nil
        selectedFileURL = nil
        document = nil
    }

    func requestNewFile() {
        newFileRequestID += 1
    }

    /// Wechselt die geöffnete Datei. Speichert die vorherige.
    func select(_ url: URL?) {
        guard url != document?.url else { return }
        document?.saveNow()
        selectedFileURL = url
        guard let url else { document = nil; return }
        // Kein Reindex-Hook nach dem Speichern: FSEvents feuert auch für unsere eigenen
        // Schreibvorgänge und löst `ProjectFolder.refresh()` samt Reindex aus.
        document = EditorDocument(url: url)
    }

    /// Reaktion auf Ordnerereignisse: verschwundene Datei abwählen, sonst sauberes Dokument neu laden.
    func handleProjectChange() {
        guard let document else { return }
        if !FileManager.default.fileExists(atPath: document.url.path) {
            // Sonst würde der Autosave in `select(nil)` die gelöschte Datei neu anlegen.
            document.discardPendingChanges()
            select(nil)
        } else {
            document.reloadIfClean()
        }
    }
}
