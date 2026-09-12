import Foundation
import Testing
@testable import GuerkchenCore

@Suite @MainActor struct ProjectFolderTests {
    @Test func loadsTreeAndIndexOnInit() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("a.feature", "Feature: A\n  Scenario: S\n    Given step a")
        let project = try ProjectFolder(rootURL: p.root, watch: false)
        #expect(project.tree.children?.map(\.name) == ["a.feature"])
        #expect(project.steps(for: "en") == ["step a"])
    }

    @Test func mutationsRefreshTreeAndIndex() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let project = try ProjectFolder(rootURL: p.root, watch: false)
        let file = try project.createFeatureFile(in: p.root, name: "b")
        #expect(project.tree.children?.map(\.name) == ["b.feature"])
        let dir = try project.createFolder(in: p.root, name: "sub")
        #expect(project.tree.children?.map(\.name) == ["sub", "b.feature"])
        let renamed = try project.rename(file, to: "c")
        #expect(project.tree.children?.map(\.name) == ["sub", "c.feature"])
        try project.trash(renamed)
        try project.trash(dir)
        #expect(project.tree.children == [])
    }

    @Test func rebuildIndexPicksUpExternalWrites() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let project = try ProjectFolder(rootURL: p.root, watch: false)
        try p.write("x.feature", "Given written later")
        #expect(project.steps(for: "en") == [])
        project.rebuildIndex()
        #expect(project.steps(for: "en") == ["written later"])
    }

    @Test func watcherFiresOnChange() async throws {
        let p = try TempProject(); defer { p.cleanup() }
        let project = try ProjectFolder(rootURL: p.root, watch: true)
        let before = project.changeCounter
        try p.write("new.feature", "Feature: N")
        for _ in 0..<40 where project.changeCounter == before {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(project.changeCounter > before)
        #expect(project.tree.children?.map(\.name) == ["new.feature"])
    }
}
