import Foundation
import Observation

@MainActor
@Observable
final class EditorDocument {
    let url: URL
    private(set) var text: String = ""
    private(set) var isDirty = false
    private(set) var loadError: String?
    private(set) var saveError: String?
    @ObservationIgnored var onSaved: (() -> Void)?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?

    static let autosaveDelay: Duration = .seconds(1)

    init(url: URL) {
        self.url = url
        load()
    }

    func updateText(_ newText: String) {
        guard newText != text else { return }
        text = newText
        isDirty = true
        scheduleAutosave()
    }

    func saveNow() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard isDirty, loadError == nil else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDirty = false
            saveError = nil
            onSaved?()
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Lädt die Datei neu, wenn der Editor keine ungesicherten Änderungen hat.
    func reloadIfClean() {
        guard !isDirty else { return }
        guard let disk = readFromDisk() else { return }
        if disk != text { text = disk }
    }

    private func load() {
        if let content = readFromDisk() {
            text = content
            loadError = nil
        } else {
            text = ""
            loadError = "Die Datei „\(url.lastPathComponent)“ ist kein gültiges UTF-8 oder konnte nicht gelesen werden."
        }
    }

    private func readFromDisk() -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
}
