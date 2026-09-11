import Testing
@testable import GuerkchenCore

@Suite struct LineScannerTests {
    let en = GherkinLanguages.english
    let de = GherkinLanguages.dialect(for: "de")!

    private func kinds(_ text: String, _ dialect: GherkinDialect) -> [LineKind] {
        LineScanner.scan(text, dialect: dialect).map(\.kind)
    }

    private func keywordText(_ text: String, line: Int, _ dialect: GherkinDialect) -> (String, String)? {
        let scanned = LineScanner.scan(text, dialect: dialect)[line]
        guard case let .keyword(_, keywordRange, textRange) = scanned.kind else { return nil }
        return (String(text[keywordRange]), String(text[textRange]))
    }

    @Test func languageCodeOnlyOnFirstLine() {
        #expect(LineScanner.languageCode(in: "# language: de\nFunktionalität: X") == "de")
        #expect(LineScanner.languageCode(in: "#language:DE") == "de")
        #expect(LineScanner.languageCode(in: "  #  language :  fr  \n") == "fr")
        #expect(LineScanner.languageCode(in: "Feature: X\n# language: de") == nil)
        #expect(LineScanner.languageCode(in: "# comment") == nil)
        #expect(LineScanner.languageCode(in: "") == nil)
    }

    @Test func dialectFallsBackToEnglish() {
        #expect(LineScanner.dialect(for: "# language: de\n").code == "de")
        #expect(LineScanner.dialect(for: "# language: zz\n").code == "en")
        #expect(LineScanner.dialect(for: "Feature: X").code == "en")
    }

    @Test func classifiesBasicLines() {
        let text = """
        # language: en
        @smoke @fast
        Feature: Login
          Some description
          # a comment

          Background:
            Given a user
          Scenario Outline: Try <name>
            When I type "<name>"
            Then it works
            And more
            But not this
            * star step
            Examples:
              | name |
              | Bob  |
        """
        let actual = kinds(text, en)
        #expect(actual[0] == .languageLine(code: "en"))
        #expect(actual[1] == .tag)
        if case .keyword(let c, _, _) = actual[2] { #expect(c == .feature) } else { Issue.record("feature") }
        #expect(actual[3] == .other)
        #expect(actual[4] == .comment)
        #expect(actual[5] == .blank)
        if case .keyword(let c, _, _) = actual[6] { #expect(c == .background) } else { Issue.record("background") }
        if case .keyword(let c, _, _) = actual[7] { #expect(c == .given) } else { Issue.record("given") }
        if case .keyword(let c, _, _) = actual[8] { #expect(c == .scenarioOutline) } else { Issue.record("outline") }
        if case .keyword(let c, _, _) = actual[9] { #expect(c == .when) } else { Issue.record("when") }
        if case .keyword(let c, _, _) = actual[10] { #expect(c == .then) } else { Issue.record("then") }
        if case .keyword(let c, _, _) = actual[11] { #expect(c == .and) } else { Issue.record("and") }
        if case .keyword(let c, _, _) = actual[12] { #expect(c == .but) } else { Issue.record("but") }
        if case .keyword(let c, _, _) = actual[13] { #expect(c == .given) } else { Issue.record("star") }
        if case .keyword(let c, _, _) = actual[14] { #expect(c == .examples) } else { Issue.record("examples") }
        #expect(actual[15] == .tableRow)
        #expect(actual[16] == .tableRow)
        #expect(actual.count == 17)
    }

    @Test func keywordAndTextRanges() {
        let text = "Feature: Login\n  Given   a user is logged in\n  Scenario Outline: X"
        let feature = keywordText(text, line: 0, en)
        #expect(feature?.0 == "Feature")
        #expect(feature?.1 == " Login")
        let given = keywordText(text, line: 1, en)
        #expect(given?.0 == "Given")
        #expect(given?.1 == "   a user is logged in")
        let outline = keywordText(text, line: 2, en)
        #expect(outline?.0 == "Scenario Outline")
        #expect(outline?.1 == " X")
    }

    @Test func blockKeywordRequiresColon() {
        // "Feature Login" ohne Doppelpunkt ist kein Schlüsselwort
        #expect(kinds("Feature Login", en) == [.other])
        // "Scenario:" ohne Text ist ein Schlüsselwort mit leerem Text
        let scanned = LineScanner.scan("Scenario:", dialect: en)
        if case let .keyword(c, _, textRange) = scanned[0].kind {
            #expect(c == .scenario)
            #expect(textRange.isEmpty)
        } else { Issue.record("expected keyword") }
    }

    @Test func stepKeywordRequiresSpaceOrEndOfLine() {
        #expect(kinds("Givenx", en) == [.other])
        if case .keyword(let c, _, _) = kinds("Given", en)[0] { #expect(c == .given) } else { Issue.record("bare Given") }
        if case .keyword(let c, _, _) = kinds("  Given ", en)[0] { #expect(c == .given) } else { Issue.record("Given with space") }
    }

    @Test func germanDialect() {
        let text = "# language: de\nFunktionalität: Anmeldung\n  Szenario: Login\n    Gegeben sei ein Nutzer\n    Wenn er klickt\n    Dann klappt es"
        let actual = kinds(text, de)
        if case .keyword(let c, _, _) = actual[1] { #expect(c == .feature) } else { Issue.record("feature") }
        if case .keyword(let c, _, _) = actual[2] { #expect(c == .scenario) } else { Issue.record("scenario") }
        let given = keywordText(text, line: 3, de)
        #expect(given?.0 == "Gegeben sei")
        #expect(given?.1 == " ein Nutzer")
        if case .keyword(let c, _, _) = actual[4] { #expect(c == .when) } else { Issue.record("when") }
        if case .keyword(let c, _, _) = actual[5] { #expect(c == .then) } else { Issue.record("then") }
    }

    @Test func docStringsSwallowEverything() {
        let text = "Given x\n\"\"\"\n# not a comment\nGiven not a step\n| not | a table |\n\"\"\"\nThen y\n```\ncontent\n```"
        let actual = kinds(text, en)
        #expect(actual[1] == .docStringDelimiter)
        #expect(actual[2] == .docStringContent)
        #expect(actual[3] == .docStringContent)
        #expect(actual[4] == .docStringContent)
        #expect(actual[5] == .docStringDelimiter)
        if case .keyword(let c, _, _) = actual[6] { #expect(c == .then) } else { Issue.record("then") }
        #expect(actual[7] == .docStringDelimiter)
        #expect(actual[8] == .docStringContent)
        #expect(actual[9] == .docStringDelimiter)
    }

    @Test func unknownLanguageLineIsComment() {
        // Der Aufrufer wählt den Dialekt; eine erste Zeile mit unbekanntem Code bleibt languageLine,
        // damit die UI sie färben kann. Ohne "language:" ist es ein Kommentar.
        #expect(kinds("# language: zz", en) == [.languageLine(code: "zz")])
        #expect(kinds("# hello", en) == [.comment])
    }

    @Test func lineRangesExcludeNewlinesAndKeepTrailingEmptyLine() {
        let text = "Feature: A\n\n"
        let scanned = LineScanner.scan(text, dialect: en)
        #expect(scanned.count == 3)
        #expect(String(text[scanned[0].range]) == "Feature: A")
        #expect(scanned[1].kind == .blank)
        #expect(scanned[2].kind == .blank)
        #expect(scanned[2].range.isEmpty)
        #expect(LineScanner.scan("", dialect: en).count == 1)
    }

    @Test func crlfIsHandled() {
        let scanned = LineScanner.scan("Feature: A\r\nGiven b\r\n", dialect: en)
        #expect(String("Feature: A\r\nGiven b\r\n"[scanned[0].range]) == "Feature: A")
        if case .keyword(let c, _, _) = scanned[1].kind { #expect(c == .given) } else { Issue.record("given") }
    }
}
