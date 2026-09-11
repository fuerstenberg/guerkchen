import Testing
@testable import GuerkchenCore

@Suite struct SuggestEngineTests {
    let en = GherkinLanguages.english
    let de = GherkinLanguages.dialect(for: "de")!
    let steps = ["a user is logged in", "a user exists", "the cart is empty", "I click login"]

    /// Cursor am Zeilenende
    private func suggest(_ line: String, dialect: GherkinDialect? = nil, steps: [String]? = nil,
                         inDocString: Bool = false, isFirstLine: Bool = false) -> [Suggestion] {
        SuggestEngine.suggestions(line: line, cursor: line.endIndex, dialect: dialect ?? en,
                                  steps: steps ?? self.steps, isFirstLine: isFirstLine, inDocString: inDocString)
    }

    private func labels(_ line: String, dialect: GherkinDialect? = nil) -> [String] {
        suggest(line, dialect: dialect).map(\.label)
    }

    // Die vier Beispiele aus der Anfrage
    @Test func typingGSuggestsGiven() {
        #expect(labels("g").first == "Given")
    }

    @Test func typingBSuggestsBackground() {
        #expect(labels("b").contains("Background"))
        #expect(labels("b").first == "But" || labels("b").first == "Background")
    }

    @Test func typingAfterGivenSuggestsExistingSteps() {
        let result = suggest("Given a u")
        #expect(result.first?.label == "a user exists" || result.first?.label == "a user is logged in")
        #expect(result.allSatisfy { $0.kind == .step })
        #expect(!result.map(\.label).contains("the cart is empty"))
    }

    @Test func typingScSuggestsScenarioAndOutline() {
        let result = labels("sc")
        #expect(result.contains("Scenario"))
        #expect(result.contains("Scenario Outline"))
        #expect(result.first == "Scenario")
    }

    @Test func keywordInsertionAddsColonOrSpace() {
        let feature = suggest("Fea").first!
        #expect(feature.insertion == "Feature: ")
        #expect(feature.kind == .keyword(.feature))
        let given = suggest("Giv").first!
        #expect(given.insertion == "Given ")
        #expect(given.kind == .keyword(.given))
    }

    @Test func keywordReplacementCoversTypedWordAfterIndentation() {
        let line = "    Scenario O"
        let s = suggest(line).first!
        #expect(s.label == "Scenario Outline")
        #expect(String(line[s.replacementRange]) == "Scenario O")
    }

    @Test func stepReplacementCoversWholeRestOfLine() {
        let line = "  Given a user is logged"
        let s = suggest(line).first!
        #expect(String(line[s.replacementRange]) == "a user is logged")
        #expect(s.insertion == s.label)
    }

    @Test func stepModeWithEmptyQueryListsAllStepsAlphabetically() {
        let result = labels("When ")
        #expect(result == ["a user exists", "a user is logged in", "I click login", "the cart is empty"])
    }

    @Test func exactlyTypedStepIsExcluded() {
        #expect(!labels("Then the cart is empty").contains("the cart is empty"))
        #expect(!labels("Then THE CART IS EMPTY").contains("the cart is empty"))
    }

    @Test func andAndButAlsoGetStepSuggestions() {
        #expect(!labels("And a").isEmpty)
        #expect(!labels("But I").isEmpty)
    }

    @Test func noSuggestionsInCommentsTagsTablesDocStrings() {
        #expect(suggest("# g").isEmpty)
        #expect(suggest("@sm").isEmpty)
        #expect(suggest("| a").isEmpty)
        #expect(suggest("\"\"\"").isEmpty)
        #expect(suggest("Given a", inDocString: true).isEmpty)
        #expect(suggest("* a").isEmpty)
        #expect(suggest("# language: e", isFirstLine: true).isEmpty)
    }

    @Test func noSuggestionsAfterBlockKeywordColon() {
        #expect(suggest("Feature: Lo").isEmpty)
        #expect(suggest("Scenario: ").isEmpty)
    }

    @Test func noSuggestionsForEmptyOrIndentOnly() {
        #expect(suggest("").isEmpty)
        #expect(suggest("    ").isEmpty)
    }

    @Test func cursorInMiddleOfLineUsesOnlyPrefix() {
        let line = "Giv rest of line"
        let cursor = line.index(line.startIndex, offsetBy: 3)
        let result = SuggestEngine.suggestions(line: line, cursor: cursor, dialect: en, steps: steps,
                                               isFirstLine: false, inDocString: false)
        #expect(result.first?.label == "Given")
        #expect(String(line[result.first!.replacementRange]) == "Giv")
    }

    @Test func limitIsRespected() {
        let many = (0..<30).map { "step \($0)" }
        let result = suggest("Given s", steps: many)
        #expect(result.count == 10)
    }

    @Test func germanKeywords() {
        let result = labels("ge", dialect: de)
        #expect(result.contains("Gegeben sei"))
        #expect(result.contains("Gegeben seien"))
        let step = suggest("Angenommen ein", dialect: de, steps: ["ein Nutzer existiert"])
        #expect(step.first?.label == "ein Nutzer existiert")
    }

    @Test func modeDetection() {
        let line = "Given "
        let m = SuggestEngine.mode(line: line, cursor: line.endIndex, dialect: en, isFirstLine: false, inDocString: false)
        if case .step(let query, _) = m { #expect(query == "") } else { Issue.record("expected step mode") }
        let k = SuggestEngine.mode(line: "Gi", cursor: "Gi".endIndex, dialect: en, isFirstLine: false, inDocString: false)
        if case .keyword(let query, _) = k { #expect(query == "Gi") } else { Issue.record("expected keyword mode") }
        #expect(SuggestEngine.mode(line: "Given", cursor: "Given".endIndex, dialect: en, isFirstLine: false, inDocString: false)
                == .keyword(query: "Given", replacementRange: "Given".startIndex..<"Given".endIndex))
    }

    @Test func idsAreUniquePerKindAndText() {
        let ids = suggest("a").map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
