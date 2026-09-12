import Foundation
import Observation

@MainActor
@Observable
public final class ProjectFolder {
    public let rootURL: URL
    public private(set) var tree: FileNode
    public private(set) var stepIndex: StepIndex
    public private(set) var changeCounter = 0

    @ObservationIgnored private var watcher: FolderWatcher?

    public init(rootURL: URL, watch: Bool = true) throws {
        let root = rootURL.standardizedFileURL
        self.rootURL = root
        self.tree = try FileTreeBuilder.build(root: root)
        self.stepIndex = StepIndex.build(root: root)
        if watch {
            watcher = FolderWatcher(url: root) { [weak self] in
                guard let self else { return }
                self.changeCounter += 1
                self.refresh()
            }
            watcher?.start()
        }
    }

    public func refresh() {
        if let newTree = try? FileTreeBuilder.build(root: rootURL) {
            tree = newTree
        }
        rebuildIndex()
    }

    public func rebuildIndex() {
        stepIndex = StepIndex.build(root: rootURL)
    }

    public func steps(for languageCode: String) -> [String] {
        stepIndex.steps(for: languageCode)
    }

    public func createFeatureFile(in directory: URL, name: String) throws -> URL {
        defer { refresh() }
        return try FileOperations.createFeatureFile(in: directory, name: name)
    }

    public func createFolder(in directory: URL, name: String) throws -> URL {
        defer { refresh() }
        return try FileOperations.createFolder(in: directory, name: name)
    }

    public func rename(_ url: URL, to newName: String) throws -> URL {
        defer { refresh() }
        return try FileOperations.rename(url, to: newName)
    }

    public func trash(_ url: URL) throws {
        defer { refresh() }
        try FileOperations.trash(url)
    }
}
