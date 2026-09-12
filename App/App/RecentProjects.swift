import Foundation
import Observation

/// Zuletzt geöffnete Projektordner als Security-Scoped Bookmarks (Sandbox).
@MainActor
@Observable
final class RecentProjects {
    private static let key = "recentProjectBookmarks"
    private static let maxCount = 10

    private(set) var urls: [URL] = []
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil) else { return }
        var bookmarks = storedBookmarks().filter { resolve($0)?.path != url.path }
        bookmarks.insert(bookmark, at: 0)
        bookmarks = Array(bookmarks.prefix(Self.maxCount))
        defaults.set(bookmarks, forKey: Self.key)
        load()
    }

    func remove(_ url: URL) {
        let bookmarks = storedBookmarks().filter { resolve($0)?.path != url.path }
        defaults.set(bookmarks, forKey: Self.key)
        load()
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
        load()
    }

    private func storedBookmarks() -> [Data] {
        defaults.array(forKey: Self.key) as? [Data] ?? []
    }

    private func load() {
        urls = storedBookmarks().compactMap { data in
            guard let url = resolve(data) else { return nil }
            _ = url.startAccessingSecurityScopedResource()
            return url
        }
    }

    private func resolve(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
