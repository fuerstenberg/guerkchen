import Foundation

public enum FileOperationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidName(String)
    case alreadyExists(URL)

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Der Name darf nicht leer sein."
        case .invalidName(let name): return "\u{201E}\(name)\u{201D} ist kein g\u{00FC}ltiger Name. \u{201E}/\u{201D} und \u{201E}:\u{201D} sind nicht erlaubt."
        case .alreadyExists(let url): return "\u{201E}\(url.lastPathComponent)\u{201D} existiert bereits."
        }
    }
}

public enum FileOperations {
    public static func normalizedFeatureName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasSuffix(".feature") ? trimmed : trimmed + ".feature"
    }

    public static func createFeatureFile(in directory: URL, name: String) throws -> URL {
        let fileName = normalizedFeatureName(try validated(name))
        let url = directory.appendingPathComponent(fileName).standardizedFileURL
        try ensureAbsent(url)
        let title = String(fileName.dropLast(".feature".count))
        try "Feature: \(title)\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public static func createFolder(in directory: URL, name: String) throws -> URL {
        let url = directory.appendingPathComponent(try validated(name), isDirectory: true).standardizedFileURL
        try ensureAbsent(url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    public static func rename(_ url: URL, to newName: String) throws -> URL {
        let source = url.standardizedFileURL
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir)
        let name = isDir.boolValue ? try validated(newName) : normalizedFeatureName(try validated(newName))
        let target = source.deletingLastPathComponent().appendingPathComponent(name, isDirectory: isDir.boolValue).standardizedFileURL
        if target == source { return source }
        // Allow case-only renames on case-insensitive filesystems (e.g., default APFS)
        if target.path.caseInsensitiveCompare(source.path) != .orderedSame {
            try ensureAbsent(target)
        }
        try FileManager.default.moveItem(at: source, to: target)
        return target
    }

    public static func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    private static func validated(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw FileOperationError.emptyName }
        if trimmed.contains("/") || trimmed.contains(":") { throw FileOperationError.invalidName(trimmed) }
        return trimmed
    }

    private static func ensureAbsent(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { throw FileOperationError.alreadyExists(url) }
    }
}
