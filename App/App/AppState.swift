import AppKit
import Foundation
import Observation
import GuerkchenCore

@MainActor
@Observable
final class AppState {
    var project: ProjectFolder?
    var selectedFileURL: URL?
    var errorMessage: String?
    var newFileRequestID = 0
    let recent = RecentProjects()

    init() {
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
        do {
            project = try ProjectFolder(rootURL: url)
            selectedFileURL = nil
            recent.add(url)
        } catch {
            errorMessage = "Der Ordner „\(url.lastPathComponent)“ konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    func closeProject() {
        project = nil
        selectedFileURL = nil
    }

    func requestNewFile() {
        newFileRequestID += 1
    }
}
