import Foundation
import Testing
@testable import GuerkchenCore

@Suite struct StepIndexTests {
    @Test func collectsStepsWithoutKeywordsAndDeduplicates() {
        let text = """
        Feature: Login
          Scenario: A
            Given a user is logged in
            When   the user clicks login
            Then a user is logged in
            And the cart is empty
            But the cart is empty
            * a star step
          Scenario: B
            Given a user is logged in
        """
        let index = StepIndex.build(texts: [text])
        #expect(index.languages == ["en"])
        #expect(index.steps(for: "en") == ["a star step", "a user is logged in", "the cart is empty", "the user clicks login"])
    }

    @Test func separatesLanguages() {
        let en = "Feature: X\n  Scenario: Y\n    Given an english step"
        let de = "# language: de\nFunktionalität: X\n  Szenario: Y\n    Gegeben sei ein deutscher Schritt\n    Wenn etwas passiert"
        let index = StepIndex.build(texts: [en, de])
        #expect(index.steps(for: "en") == ["an english step"])
        #expect(index.steps(for: "de") == ["ein deutscher Schritt", "etwas passiert"])
        #expect(index.steps(for: "fr") == [])
        #expect(index.languages == ["de", "en"])
    }

    @Test func ignoresEmptyStepsCommentsTablesDocStrings() {
        let text = "Given \nGiven\n# Given not\n| Given | no |\n\"\"\"\nGiven inside doc\n\"\"\"\nWhen real"
        let index = StepIndex.build(texts: [text])
        #expect(index.steps(for: "en") == ["real"])
    }

    @Test func unknownLanguageFallsBackToEnglish() {
        let index = StepIndex.build(texts: ["# language: zz\nGiven fallback"])
        #expect(index.steps(for: "en") == ["fallback"])
    }

    @Test func buildsFromFolderAndSkipsInvalidUTF8() throws {
        let p = try TempProject(); defer { p.cleanup() }
        try p.write("a.feature", "Feature: A\n  Scenario: S\n    Given step from a")
        try p.write("sub/b.feature", "# language: de\nFunktionalität: B\n  Szenario: S\n    Wenn Schritt aus b")
        try p.write("ignored.txt", "Given not indexed")
        let bad = p.root.appendingPathComponent("bad.feature")
        try Data([0xFF, 0xFE, 0x00, 0x47, 0x69, 0x76, 0x65, 0x6E]).write(to: bad)

        let index = StepIndex.build(root: p.root)
        #expect(index.steps(for: "en") == ["step from a"])
        #expect(index.steps(for: "de") == ["Schritt aus b"])
    }

    @Test func addAccumulates() {
        var index = StepIndex()
        index.add(text: "Given one")
        index.add(text: "Given two\nGiven one")
        #expect(index.steps(for: "en") == ["one", "two"])
    }
}
