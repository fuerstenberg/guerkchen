import Foundation

public struct FileNode: Identifiable, Hashable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let children: [FileNode]?

    public var id: URL { url }
    public var isFeatureFile: Bool { !isDirectory && url.pathExtension.lowercased() == "feature" }

    public init(url: URL, name: String, isDirectory: Bool, children: [FileNode]?) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.children = children
    }
}

public enum FileTreeBuilder {
    private static let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey, .isSymbolicLinkKey]

    public static func build(root: URL) throws -> FileNode {
        let root = root.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        return FileNode(url: root, name: root.lastPathComponent, isDirectory: true, children: try children(of: root))
    }

    public static func featureFiles(under root: URL) -> [URL] {
        guard let tree = try? build(root: root) else { return [] }
        var result: [URL] = []
        func walk(_ node: FileNode) {
            if node.isFeatureFile { result.append(node.url) }
            node.children?.forEach(walk)
        }
        walk(tree)
        return result.sorted { $0.path < $1.path }
    }

    private static func children(of directory: URL) throws -> [FileNode] {
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        var nodes: [FileNode] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.isSymbolicLink != true else { continue }
            let url = entry.standardizedFileURL
            let name = values.name ?? url.lastPathComponent
            if values.isDirectory == true {
                let subchildren = (try? children(of: url)) ?? []
                nodes.append(FileNode(url: url, name: name, isDirectory: true, children: subchildren))
            } else if url.pathExtension.lowercased() == "feature" {
                nodes.append(FileNode(url: url, name: name, isDirectory: false, children: nil))
            }
        }
        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
