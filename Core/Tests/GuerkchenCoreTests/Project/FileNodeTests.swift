import Foundation
import Testing
@testable import GuerkchenCore

/// Legt einen temporären Projektordner an und räumt ihn nach dem Test weg.
struct TempProject {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("guerkchen-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    @discardableResult
    func write(_ relativePath: String, _ content: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    func mkdir(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

@Suite struct FileNodeTests {
    @Test func buildsFilteredSortedTree() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("zeta.feature", "Feature: Z")
        try p.write("alpha.feature", "Feature: A")
        try p.write("README.md", "ignored")
        try p.write(".hidden.feature", "ignored")
        try p.write("sub/inner.feature", "Feature: I")
        _ = try p.mkdir("empty")
        _ = try p.mkdir(".git")

        let tree = try FileTreeBuilder.build(root: p.root)
        #expect(tree.isDirectory)
        #expect(tree.name == p.root.lastPathComponent)
        let names = tree.children!.map(\.name)
        #expect(names == ["empty", "sub", "alpha.feature", "zeta.feature"])
        let sub = tree.children![1]
        #expect(sub.children?.map(\.name) == ["inner.feature"])
        #expect(tree.children![0].children == [])
        #expect(tree.children![2].children == nil)
        #expect(tree.children![2].isFeatureFile)
        #expect(!tree.children![0].isFeatureFile)
    }

    @Test func featureFilesRecursive() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("b.feature", "")
        try p.write("a/c.feature", "")
        try p.write("a/notes.txt", "")
        let files = FileTreeBuilder.featureFiles(under: p.root).map { $0.lastPathComponent }
        #expect(files == ["c.feature", "b.feature"])
    }

    @Test func idEqualsStandardizedURL() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("a.feature", "")
        let tree = try FileTreeBuilder.build(root: p.root)
        let node = tree.children![0]
        #expect(node.id == node.url)
        #expect(node.url == p.root.appendingPathComponent("a.feature").standardizedFileURL)
    }

    @Test func missingRootThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent/guerkchen-\(UUID().uuidString)")
        #expect(throws: (any Error).self) { try FileTreeBuilder.build(root: missing) }
    }

    @Test func skipsSymbolicLinks() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("real/a.feature", "Feature: A")

        // Create directory symlink loop
        let loopURL = p.root.appendingPathComponent("loop", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: loopURL, withDestinationURL: p.root)

        // Create file symlink
        let linkFileURL = p.root.appendingPathComponent("link.feature")
        try FileManager.default.createSymbolicLink(at: linkFileURL, withDestinationURL: p.root.appendingPathComponent("real/a.feature"))

        let tree = try FileTreeBuilder.build(root: p.root)
        let names = tree.children!.map(\.name)
        #expect(names == ["real"])

        let files = FileTreeBuilder.featureFiles(under: p.root).map { $0.lastPathComponent }
        #expect(files == ["a.feature"])
    }

    @Test func unreadableSubdirectoryYieldsEmptyChildren() throws {
        guard getuid() != 0 else { return }

        let p = try TempProject(); defer { p.cleanup() }
        let lockedURL = try p.mkdir("locked")
        try p.write("locked/x.feature", "Feature: X")

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedURL.path) }

        let tree = try FileTreeBuilder.build(root: p.root)
        let lockedNode = tree.children!.first { $0.name == "locked" }
        #expect(lockedNode != nil)
        #expect(lockedNode!.children == [])
    }
}
