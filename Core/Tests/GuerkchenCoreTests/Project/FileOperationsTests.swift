import Foundation
import Testing
@testable import GuerkchenCore

@Suite struct FileOperationsTests {
    @Test func normalizesFeatureName() {
        #expect(FileOperations.normalizedFeatureName("login") == "login.feature")
        #expect(FileOperations.normalizedFeatureName("  login.feature ") == "login.feature")
        #expect(FileOperations.normalizedFeatureName("Login.FEATURE") == "Login.FEATURE")
    }

    @Test func createsFeatureFileWithHeader() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let url = try FileOperations.createFeatureFile(in: p.root, name: "checkout")
        #expect(url.lastPathComponent == "checkout.feature")
        #expect(try String(contentsOf: url, encoding: .utf8) == "Feature: checkout\n")
    }

    @Test func createRejectsDuplicatesAndBadNames() throws {
        let p = try TempProject(); defer { p.cleanup() }
        _ = try FileOperations.createFeatureFile(in: p.root, name: "a")
        #expect(throws: FileOperationError.alreadyExists(p.root.appendingPathComponent("a.feature").standardizedFileURL)) {
            try FileOperations.createFeatureFile(in: p.root, name: "a")
        }
        #expect(throws: FileOperationError.emptyName) { try FileOperations.createFeatureFile(in: p.root, name: "   ") }
        #expect(throws: FileOperationError.invalidName("x/y")) { try FileOperations.createFeatureFile(in: p.root, name: "x/y") }
        #expect(throws: FileOperationError.invalidName("x:y")) { try FileOperations.createFolder(in: p.root, name: "x:y") }
    }

    @Test func createsFolder() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let url = try FileOperations.createFolder(in: p.root, name: "specs")
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue)
    }

    @Test func renamesFileAddingExtensionAndRejectsExisting() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let a = try p.write("a.feature", "Feature: A")
        try p.write("c.feature", "Feature: C")
        let b = try FileOperations.rename(a, to: "b")
        #expect(b.lastPathComponent == "b.feature")
        #expect(!FileManager.default.fileExists(atPath: a.path))
        #expect(try String(contentsOf: b, encoding: .utf8) == "Feature: A")
        #expect(throws: FileOperationError.alreadyExists(p.root.appendingPathComponent("c.feature").standardizedFileURL)) {
            try FileOperations.rename(b, to: "c.feature")
        }
        // gleicher Name: No-op
        #expect(try FileOperations.rename(b, to: "b.feature") == b.standardizedFileURL)
    }

    @Test func renamesFolderWithoutExtension() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let dir = try p.mkdir("old")
        let renamed = try FileOperations.rename(dir, to: "new")
        #expect(renamed.lastPathComponent == "new")
    }

    @Test func trashRemovesFromFolder() throws {
        let p = try TempProject(); defer { p.cleanup() }
        let a = try p.write("a.feature", "")
        try FileOperations.trash(a)
        #expect(!FileManager.default.fileExists(atPath: a.path))
    }
}
