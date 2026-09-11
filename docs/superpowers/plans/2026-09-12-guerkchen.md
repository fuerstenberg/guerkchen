# guerkchen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein macOS-Editor für Gherkin-`.feature`-Dateien mit Projektordner, Dateibaum, Syntaxfärbung und einem Suggest-Dropdown, das Schlüsselwörter und bereits vorhandene Step-Texte vorschlägt.

**Architecture:** Ein lokales Swift-Package `Core` (GuerkchenCore) enthält die drei UI-freien Schichten Gherkin (Dialekte, Zeilen-Scanner), Project (Dateibaum, Step-Index, Ordnerbeobachtung, Dateioperationen) und Suggest (Modus-Erkennung, Fuzzy-Bewertung). Die App ist ein XcodeGen-Target mit SwiftUI-Shell; der Editor ist ein `NSTextView` in einem `NSViewRepresentable`, das Dropdown ein rahmenloses Kind-`NSPanel`.

**Tech Stack:** Swift 6.3 / Xcode 26.6, SwiftUI, AppKit, Observation, Swift Testing, XcodeGen 2.46, FSEvents. Keine Fremdabhängigkeiten.

**Spec:** `docs/superpowers/specs/2026-09-12-guerkchen-design.md`

## Global Constraints

- Ziel-Plattform: macOS 15.0 (`platforms: [.macOS(.v15)]`, `deploymentTarget macOS "15.0"`).
- Package `Core` im Swift-6-Sprachmodus (`swift-tools-version: 6.0`). App-Target im Swift-5-Sprachmodus (`SWIFT_VERSION: 5.0`), damit AppKit-Bridging ohne Isolationsfehler bleibt.
- Keine Fremdabhängigkeiten (kein SPM-Fremdpaket, kein CocoaPods).
- Sprachzeile ausschließlich in der Form `# language: xx` auf der ersten Zeile; fehlt sie oder ist der Code unbekannt, gilt `en`.
- Fuzzy-Matching, max. 10 Vorschläge, Vorschläge erscheinen automatisch beim Tippen.
- Step-Vorschläge: alle Step-Zeilen unabhängig vom Schlüsselwort, nur aus Dateien gleicher Sprache, exakt getippter Text ausgeschlossen.
- Acht Farbkategorien: featureRule, background, scenario, step, comment, tag, table, docString; Farben als Hex-String in `UserDefaults`.
- Löschen legt immer in den Papierkorb (`trashItem`), nie endgültig.
- Alle Commit-Messages enden mit:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB
  ```
- Tests im Package laufen mit `cd Core && swift test`. Die App wird mit `xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug build` gebaut. Jeder Task muss am Ende fehlerfrei bauen bzw. testen.

---

## File Structure

```
project.yml
Core/Package.swift
Core/Sources/GuerkchenCore/Gherkin/KeywordCategory.swift      # enum der 11 Gherkin-Kategorien
Core/Sources/GuerkchenCore/Gherkin/GherkinDialect.swift       # Schlüsselwörter einer Sprache
Core/Sources/GuerkchenCore/Gherkin/GherkinLanguages.swift     # lädt gherkin-languages.json
Core/Sources/GuerkchenCore/Gherkin/LineScanner.swift          # klassifiziert Zeilen
Core/Sources/GuerkchenCore/Suggest/FuzzyMatcher.swift         # Subsequenz-Bewertung
Core/Sources/GuerkchenCore/Suggest/SuggestEngine.swift        # Modus + Vorschlagsliste
Core/Sources/GuerkchenCore/Project/FileNode.swift             # Baumknoten + Builder
Core/Sources/GuerkchenCore/Project/StepIndex.swift            # Step-Texte je Sprache
Core/Sources/GuerkchenCore/Project/FileOperations.swift       # create/rename/trash
Core/Sources/GuerkchenCore/Project/FolderWatcher.swift        # FSEvents
Core/Sources/GuerkchenCore/Project/ProjectFolder.swift        # @Observable Fassade
Core/Sources/GuerkchenCore/Resources/gherkin-languages.json
Core/Tests/GuerkchenCoreTests/Gherkin/GherkinLanguagesTests.swift
Core/Tests/GuerkchenCoreTests/Gherkin/LineScannerTests.swift
Core/Tests/GuerkchenCoreTests/Suggest/FuzzyMatcherTests.swift
Core/Tests/GuerkchenCoreTests/Suggest/SuggestEngineTests.swift
Core/Tests/GuerkchenCoreTests/Project/FileNodeTests.swift
Core/Tests/GuerkchenCoreTests/Project/StepIndexTests.swift
Core/Tests/GuerkchenCoreTests/Project/FileOperationsTests.swift
App/App/GuerkchenApp.swift                # @main, Fenster, Menüs, Settings-Szene
App/App/AppState.swift                    # offenes Projekt, ausgewählte Datei, Dokument
App/App/RecentProjects.swift              # Security-Scoped Bookmarks
App/UI/Theme/HighlightCategory.swift      # 8 Kategorien + Zuordnung von KeywordCategory
App/UI/Theme/ColorSettings.swift          # @Observable, UserDefaults-Hex
App/UI/Theme/NSColor+Hex.swift
App/UI/Settings/SettingsView.swift
App/UI/Sidebar/FileTreeView.swift         # Baum mit Kontextmenü
App/UI/Sidebar/RenameSheet.swift          # Namensabfrage für Anlegen/Umbenennen
App/UI/Editor/EditorDocument.swift        # Laden, Autosave, Fehler
App/UI/Editor/EditorView.swift            # SwiftUI-Hülle um den Textview
App/UI/Editor/GherkinTextView.swift       # NSViewRepresentable + Coordinator
App/UI/Editor/SyntaxHighlighter.swift     # färbt NSTextStorage
App/UI/Editor/SuggestPanel.swift          # NSPanel + SwiftUI-Liste
App/UI/Editor/SuggestController.swift     # verbindet Textview, Engine und Panel
App/UI/ContentView.swift                  # NavigationSplitView
Examples/demo-project/login.feature
Examples/demo-project/checkout.feature
Examples/demo-project/anmeldung.feature
.gitignore
```

---

### Task 1: Core-Package mit Gherkin-Dialekten

**Files:**
- Create: `.gitignore`
- Create: `Core/Package.swift`
- Create: `Core/Sources/GuerkchenCore/Resources/gherkin-languages.json` (Download)
- Create: `Core/Sources/GuerkchenCore/Gherkin/KeywordCategory.swift`
- Create: `Core/Sources/GuerkchenCore/Gherkin/GherkinDialect.swift`
- Create: `Core/Sources/GuerkchenCore/Gherkin/GherkinLanguages.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Gherkin/GherkinLanguagesTests.swift`

**Interfaces:**
- Consumes: nichts.
- Produces:
  - `enum KeywordCategory: String, CaseIterable, Sendable, Codable` mit Fällen `feature, rule, background, scenario, scenarioOutline, examples, given, when, then, and, but`, Eigenschaft `isStep: Bool`.
  - `struct GherkinDialect: Sendable, Equatable` mit `code: String`, `name: String`, `native: String`, `func keywords(for: KeywordCategory) -> [String]` (Blockwörter ohne Doppelpunkt, Stepwörter ohne Leerzeichen, `*` enthalten), `blockKeywords: [(keyword: String, category: KeywordCategory)]` und `stepKeywords: [(keyword: String, category: KeywordCategory)]`, beide nach Länge absteigend sortiert, `suggestableKeywords: [(keyword: String, category: KeywordCategory)]` (alle außer `*`, dedupliziert nach Text, Reihenfolge: Blockwörter, dann Stepwörter).
  - `enum GherkinLanguages` mit `static let all: [String: GherkinDialect]`, `static func dialect(for code: String) -> GherkinDialect?` (case-insensitive), `static let english: GherkinDialect`.

- [ ] **Step 1: .gitignore und Package-Manifest anlegen**

`.gitignore`:
```
.DS_Store
/guerkchen.xcodeproj
/build
/DerivedData
Core/.build
Core/.swiftpm
xcuserdata/
```

`Core/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuerkchenCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GuerkchenCore", targets: ["GuerkchenCore"])
    ],
    targets: [
        .target(
            name: "GuerkchenCore",
            resources: [.copy("Resources/gherkin-languages.json")]
        ),
        .testTarget(
            name: "GuerkchenCoreTests",
            dependencies: ["GuerkchenCore"]
        )
    ]
)
```

- [ ] **Step 2: Sprachdatei herunterladen**

```bash
mkdir -p Core/Sources/GuerkchenCore/Resources
curl -sSfL -o Core/Sources/GuerkchenCore/Resources/gherkin-languages.json \
  https://raw.githubusercontent.com/cucumber/gherkin/main/gherkin-languages.json
python3 -c "import json;d=json.load(open('Core/Sources/GuerkchenCore/Resources/gherkin-languages.json'));print(len(d),'languages');assert 'de' in d and 'en' in d"
```
Expected: `80 languages` (oder mehr). Die Datei steht unter MIT-Lizenz (Cucumber Ltd), das ist im Header von `GherkinLanguages.swift` vermerkt.

- [ ] **Step 3: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Gherkin/GherkinLanguagesTests.swift`:
```swift
import Testing
@testable import GuerkchenCore

@Suite struct GherkinLanguagesTests {
    @Test func englishDialectHasStandardKeywords() throws {
        let en = try #require(GherkinLanguages.dialect(for: "en"))
        #expect(en.name == "English")
        #expect(en.keywords(for: .feature) == ["Feature", "Business Need", "Ability"])
        #expect(en.keywords(for: .given) == ["*", "Given"])
        #expect(en.keywords(for: .scenarioOutline) == ["Scenario Outline", "Scenario Template"])
    }

    @Test func germanDialectIsAvailableCaseInsensitive() throws {
        let de = try #require(GherkinLanguages.dialect(for: "DE"))
        #expect(de.native == "Deutsch")
        #expect(de.keywords(for: .given).contains("Gegeben sei"))
        #expect(de.keywords(for: .scenario) == ["Beispiel", "Szenario"])
    }

    @Test func unknownCodeReturnsNil() {
        #expect(GherkinLanguages.dialect(for: "xx-nope") == nil)
    }

    @Test func blockKeywordsAreSortedLongestFirst() throws {
        let en = try #require(GherkinLanguages.dialect(for: "en"))
        let first = en.blockKeywords.first?.keyword
        #expect(first == "Scenario Template" || first == "Scenario Outline")
        #expect(en.blockKeywords.contains { $0.keyword == "Rule" && $0.category == .rule })
    }

    @Test func stepKeywordsIncludeStarAndAreLongestFirst() throws {
        let de = try #require(GherkinLanguages.dialect(for: "de"))
        #expect(de.stepKeywords.first?.keyword == "Gegeben seien")
        #expect(de.stepKeywords.contains { $0.keyword == "*" })
    }

    @Test func suggestableKeywordsExcludeStarAndDuplicates() throws {
        let en = try #require(GherkinLanguages.dialect(for: "en"))
        let texts = en.suggestableKeywords.map(\.keyword)
        #expect(!texts.contains("*"))
        #expect(Set(texts).count == texts.count)
        #expect(texts.first == "Feature")
        #expect(texts.contains("Given") && texts.contains("Scenario Outline"))
    }

    @Test func allLanguagesLoad() {
        #expect(GherkinLanguages.all.count >= 70)
        #expect(GherkinLanguages.english.code == "en")
    }

    @Test func isStep() {
        #expect(KeywordCategory.given.isStep)
        #expect(KeywordCategory.but.isStep)
        #expect(!KeywordCategory.feature.isStep)
        #expect(!KeywordCategory.examples.isStep)
    }
}
```

- [ ] **Step 4: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'GherkinLanguages' in scope`.

- [ ] **Step 5: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Gherkin/KeywordCategory.swift`:
```swift
public enum KeywordCategory: String, CaseIterable, Sendable, Codable {
    case feature, rule, background, scenario, scenarioOutline, examples
    case given, when, then, and, but

    public var isStep: Bool {
        switch self {
        case .given, .when, .then, .and, .but: return true
        default: return false
        }
    }
}
```

`Core/Sources/GuerkchenCore/Gherkin/GherkinDialect.swift`:
```swift
public struct GherkinDialect: Sendable, Equatable {
    public let code: String
    public let name: String
    public let native: String
    private let table: [KeywordCategory: [String]]

    public init(code: String, name: String, native: String, keywords: [KeywordCategory: [String]]) {
        self.code = code
        self.name = name
        self.native = native
        self.table = keywords
    }

    public func keywords(for category: KeywordCategory) -> [String] {
        table[category] ?? []
    }

    /// Feature, Rule, Background, Scenario, Scenario Outline, Examples – längste zuerst.
    public var blockKeywords: [(keyword: String, category: KeywordCategory)] {
        entries(for: KeywordCategory.allCases.filter { !$0.isStep })
    }

    /// Given, When, Then, And, But (inkl. "*") – längste zuerst.
    public var stepKeywords: [(keyword: String, category: KeywordCategory)] {
        entries(for: KeywordCategory.allCases.filter(\.isStep))
    }

    /// Kandidaten für das Schlüsselwort-Dropdown: ohne "*", ohne Duplikate.
    public var suggestableKeywords: [(keyword: String, category: KeywordCategory)] {
        var seen = Set<String>()
        var result: [(keyword: String, category: KeywordCategory)] = []
        for category in KeywordCategory.allCases {
            for keyword in keywords(for: category) where keyword != "*" && !seen.contains(keyword) {
                seen.insert(keyword)
                result.append((keyword, category))
            }
        }
        return result
    }

    private func entries(for categories: [KeywordCategory]) -> [(keyword: String, category: KeywordCategory)] {
        categories
            .flatMap { category in keywords(for: category).map { (keyword: $0, category: category) } }
            .sorted { $0.keyword.count > $1.keyword.count }
    }
}
```

`Core/Sources/GuerkchenCore/Gherkin/GherkinLanguages.swift`:
```swift
import Foundation

/// Lädt gherkin-languages.json aus dem Cucumber-Projekt (MIT License, © Cucumber Ltd).
public enum GherkinLanguages {
    public static let all: [String: GherkinDialect] = load()

    public static let english: GherkinDialect = all["en"]!

    public static func dialect(for code: String) -> GherkinDialect? {
        all[code.lowercased()]
    }

    private struct RawDialect: Decodable {
        let name: String
        let native: String
        let feature, rule, background, scenario, scenarioOutline, examples: [String]
        let given, when, then, and, but: [String]
    }

    private static func load() -> [String: GherkinDialect] {
        guard let url = Bundle.module.url(forResource: "gherkin-languages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: RawDialect].self, from: data)
        else { fatalError("gherkin-languages.json missing or invalid") }

        var result: [String: GherkinDialect] = [:]
        for (code, dialect) in raw {
            let keywords: [KeywordCategory: [String]] = [
                .feature: clean(dialect.feature), .rule: clean(dialect.rule),
                .background: clean(dialect.background), .scenario: clean(dialect.scenario),
                .scenarioOutline: clean(dialect.scenarioOutline), .examples: clean(dialect.examples),
                .given: clean(dialect.given), .when: clean(dialect.when), .then: clean(dialect.then),
                .and: clean(dialect.and), .but: clean(dialect.but),
            ]
            result[code.lowercased()] = GherkinDialect(
                code: code.lowercased(), name: dialect.name, native: dialect.native, keywords: keywords)
        }
        return result
    }

    /// Entfernt das nachgestellte Leerzeichen der Step-Schlüsselwörter ("Given " → "Given").
    private static func clean(_ list: [String]) -> [String] {
        list.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
```

- [ ] **Step 6: Tests laufen lassen**

Run: `cd Core && swift test 2>&1 | tail -20`
Expected: `Test run with 8 tests passed`.

- [ ] **Step 7: Commit**

```bash
git add .gitignore Core
git commit -m "feat(core): add GuerkchenCore package with Gherkin dialects

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 2: LineScanner

**Files:**
- Create: `Core/Sources/GuerkchenCore/Gherkin/LineScanner.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Gherkin/LineScannerTests.swift`

**Interfaces:**
- Consumes: `GherkinDialect.blockKeywords`, `.stepKeywords`, `GherkinLanguages.dialect(for:)`, `GherkinLanguages.english`.
- Produces:
  - `enum LineKind: Equatable, Sendable`: `blank`, `languageLine(code: String)`, `comment`, `tag`, `keyword(category: KeywordCategory, keywordRange: Range<String.Index>, textRange: Range<String.Index>)` (Indizes beziehen sich auf den gesamten Text), `tableRow`, `docStringDelimiter`, `docStringContent`, `other`.
  - `struct ScannedLine: Equatable, Sendable` mit `range: Range<String.Index>` (Zeile ohne Zeilenumbruch, Index im Gesamttext) und `kind: LineKind`.
  - `enum LineScanner` mit
    - `static func languageCode(in text: String) -> String?` (nur erste Zeile, Muster `# language: xx`, Whitespace-tolerant, Code lowercased),
    - `static func dialect(for text: String) -> GherkinDialect` (Code → Dialekt, sonst Englisch),
    - `static func scan(_ text: String, dialect: GherkinDialect) -> [ScannedLine]`,
    - `static func classify(_ line: Substring, in text: String, dialect: GherkinDialect, isFirstLine: Bool, inDocString: Bool) -> LineKind` (ohne Zustandsänderung; Doc-String-Zustand verwaltet `scan`).
    - `static func isDocStringDelimiter(_ line: Substring) -> Bool`.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Gherkin/LineScannerTests.swift`:
```swift
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
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'LineScanner' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Gherkin/LineScanner.swift`:
```swift
import Foundation

public enum LineKind: Equatable, Sendable {
    case blank
    case languageLine(code: String)
    case comment
    case tag
    case keyword(category: KeywordCategory, keywordRange: Range<String.Index>, textRange: Range<String.Index>)
    case tableRow
    case docStringDelimiter
    case docStringContent
    case other
}

public struct ScannedLine: Equatable, Sendable {
    public let range: Range<String.Index>
    public let kind: LineKind
}

public enum LineScanner {
    private static let languageRegex = /^\s*#\s*language\s*:\s*([A-Za-z][A-Za-z0-9_-]*)\s*$/

    /// Sprachcode aus der ersten Zeile, lowercased. Nur die offizielle Form `# language: xx`.
    public static func languageCode(in text: String) -> String? {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r\n" }
        guard let match = firstLine.firstMatch(of: languageRegex) else { return nil }
        return String(match.1).lowercased()
    }

    public static func dialect(for text: String) -> GherkinDialect {
        languageCode(in: text).flatMap(GherkinLanguages.dialect(for:)) ?? GherkinLanguages.english
    }

    public static func isDocStringDelimiter(_ line: Substring) -> Bool {
        let trimmed = line.drop(while: \.isWhitespace)
        return trimmed.hasPrefix("\"\"\"") || trimmed.hasPrefix("```")
    }

    public static func scan(_ text: String, dialect: GherkinDialect) -> [ScannedLine] {
        var result: [ScannedLine] = []
        var inDocString = false
        var lineStart = text.startIndex
        var isFirst = true

        while true {
            // Zeilenende suchen (ohne den Umbruch selbst)
            var lineEnd = lineStart
            while lineEnd < text.endIndex, text[lineEnd] != "\n", text[lineEnd] != "\r\n" {
                lineEnd = text.index(after: lineEnd)
            }
            let line = text[lineStart..<lineEnd]
            let kind = classify(line, in: text, dialect: dialect, isFirstLine: isFirst, inDocString: inDocString)
            if kind == .docStringDelimiter { inDocString.toggle() }
            result.append(ScannedLine(range: lineStart..<lineEnd, kind: kind))
            isFirst = false

            guard lineEnd < text.endIndex else { break }
            lineStart = text.index(after: lineEnd)
            if lineStart == text.endIndex {
                // Text endet mit Umbruch → eine letzte leere Zeile
                result.append(ScannedLine(range: lineStart..<lineStart, kind: .blank))
                break
            }
        }
        return result
    }

    public static func classify(_ line: Substring, in text: String, dialect: GherkinDialect,
                                isFirstLine: Bool, inDocString: Bool) -> LineKind {
        if isDocStringDelimiter(line) { return .docStringDelimiter }
        if inDocString { return .docStringContent }

        let trimmed = line.drop(while: \.isWhitespace)
        if trimmed.isEmpty { return .blank }

        if isFirstLine, let code = languageCode(in: String(line)) { return .languageLine(code: code) }
        if trimmed.hasPrefix("#") { return .comment }
        if trimmed.hasPrefix("@") { return .tag }
        if trimmed.hasPrefix("|") { return .tableRow }

        for entry in dialect.blockKeywords where trimmed.hasPrefix(entry.keyword + ":") {
            let keywordEnd = trimmed.index(trimmed.startIndex, offsetBy: entry.keyword.count)
            let textStart = trimmed.index(after: keywordEnd) // hinter dem Doppelpunkt
            return .keyword(category: entry.category,
                            keywordRange: trimmed.startIndex..<keywordEnd,
                            textRange: textStart..<line.endIndex)
        }

        for entry in dialect.stepKeywords where trimmed.hasPrefix(entry.keyword) {
            let keywordEnd = trimmed.index(trimmed.startIndex, offsetBy: entry.keyword.count)
            let isDelimited = keywordEnd == trimmed.endIndex || trimmed[keywordEnd] == " " || trimmed[keywordEnd] == "\t"
            guard isDelimited else { continue }
            return .keyword(category: entry.category,
                            keywordRange: trimmed.startIndex..<keywordEnd,
                            textRange: keywordEnd..<line.endIndex)
        }

        return .other
    }
}
```

Hinweis: `trimmed` ist ein Substring desselben Speichers wie `text`, deshalb sind seine Indizes im Gesamttext gültig.

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test 2>&1 | tail -20`
Expected: alle Tests grün (8 + 11).

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add LineScanner for Gherkin line classification

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 3: FuzzyMatcher

**Files:**
- Create: `Core/Sources/GuerkchenCore/Suggest/FuzzyMatcher.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Suggest/FuzzyMatcherTests.swift`

**Interfaces:**
- Consumes: nichts.
- Produces: `enum FuzzyMatcher` mit `static func score(query: String, candidate: String) -> Int?` (nil = kein Subsequenz-Treffer; leere Query = 0) und `static func rank(query: String, candidates: [String], limit: Int) -> [String]` (leere Query: alphabetisch; sonst Score absteigend, dann kürzer zuerst, dann alphabetisch, case-insensitive).

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Suggest/FuzzyMatcherTests.swift`:
```swift
import Testing
@testable import GuerkchenCore

@Suite struct FuzzyMatcherTests {
    @Test func noMatchReturnsNil() {
        #expect(FuzzyMatcher.score(query: "xyz", candidate: "a user") == nil)
        #expect(FuzzyMatcher.score(query: "users", candidate: "a user") == nil)
    }

    @Test func emptyQueryMatchesEverythingWithZero() {
        #expect(FuzzyMatcher.score(query: "", candidate: "anything") == 0)
    }

    @Test func caseInsensitive() {
        #expect(FuzzyMatcher.score(query: "GIV", candidate: "Given") != nil)
    }

    @Test func prefixBeatsScatteredMatch() {
        let prefix = FuzzyMatcher.score(query: "a u", candidate: "a user is logged in")!
        let scattered = FuzzyMatcher.score(query: "a u", candidate: "a menu is shown")!
        #expect(prefix > scattered)
    }

    @Test func subsequenceMatchesLikeFzf() {
        #expect(FuzzyMatcher.score(query: "aul", candidate: "a user is logged in") != nil)
        #expect(FuzzyMatcher.score(query: "sc", candidate: "Scenario Outline") != nil)
    }

    @Test func rankOrdersByScoreThenLengthThenAlphabet() {
        let ranked = FuzzyMatcher.rank(query: "sc", candidates: ["Scenario Outline", "Scenario", "Scenarios", "Given"], limit: 10)
        #expect(ranked == ["Scenario", "Scenarios", "Scenario Outline"])
    }

    @Test func rankHonorsLimitAndEmptyQuery() {
        let ranked = FuzzyMatcher.rank(query: "", candidates: ["b", "a", "c"], limit: 2)
        #expect(ranked == ["a", "b"])
    }

    @Test func wordStartBonus() {
        // "ul" trifft in "user login" zwei Wortanfänge, in "usual" nicht
        let wordStarts = FuzzyMatcher.score(query: "ul", candidate: "user login")!
        let inside = FuzzyMatcher.score(query: "ul", candidate: "usual")!
        #expect(wordStarts > inside)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter FuzzyMatcherTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'FuzzyMatcher' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Suggest/FuzzyMatcher.swift`:
```swift
public enum FuzzyMatcher {
    private static let prefixBonus = 5
    private static let consecutiveBonus = 3
    private static let wordStartBonus = 2
    private static let gapPenalty = 1

    /// Greedy Subsequenz-Suche, case-insensitive. nil wenn nicht alle Query-Zeichen
    /// in Reihenfolge im Kandidaten vorkommen.
    public static func score(query: String, candidate: String) -> Int? {
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        if q.isEmpty { return 0 }

        var score = 0
        var qi = 0
        var previousMatch: Int? = nil

        for (ci, ch) in c.enumerated() where qi < q.count {
            guard ch == q[qi] else { continue }
            score += 1
            if ci == 0 { score += prefixBonus }
            if let prev = previousMatch {
                if ci == prev + 1 {
                    score += consecutiveBonus
                } else {
                    score -= gapPenalty * (ci - prev - 1)
                }
            } else if ci > 0 {
                score -= gapPenalty * ci
            }
            if ci > 0, !c[ci - 1].isLetter, !c[ci - 1].isNumber { score += wordStartBonus }
            previousMatch = ci
            qi += 1
        }
        return qi == q.count ? score : nil
    }

    /// Leere Query: rein alphabetisch. Sonst Score absteigend, dann kürzer zuerst, dann alphabetisch.
    public static func rank(query: String, candidates: [String], limit: Int) -> [String] {
        if query.isEmpty {
            return Array(candidates
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .prefix(limit))
        }
        return candidates
            .compactMap { candidate -> (String, Int)? in
                score(query: query, candidate: candidate).map { (candidate, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.count != rhs.0.count { return lhs.0.count < rhs.0.count }
                return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test --filter FuzzyMatcherTests 2>&1 | tail -20`
Expected: 8 Tests grün. Falls `prefixBeatsScatteredMatch` oder `wordStartBonus` fehlschlägt, die Bonuskonstanten anpassen, nicht die Tests.

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add FuzzyMatcher

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 4: SuggestEngine

**Files:**
- Create: `Core/Sources/GuerkchenCore/Suggest/SuggestEngine.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Suggest/SuggestEngineTests.swift`

**Interfaces:**
- Consumes: `GherkinDialect.suggestableKeywords`, `.blockKeywords`, `.stepKeywords`, `LineScanner.isDocStringDelimiter`, `FuzzyMatcher.rank`.
- Produces:
  - `enum SuggestionKind: Equatable, Sendable { case keyword(KeywordCategory), step }`
  - `struct Suggestion: Equatable, Sendable, Identifiable` mit `id: String`, `label: String` (Anzeige), `insertion: String` (einzufügender Text), `replacementRange: Range<String.Index>` (Bereich in der übergebenen Zeile), `kind: SuggestionKind`.
  - `enum SuggestMode: Equatable, Sendable { case keyword(query: String, replacementRange: Range<String.Index>), step(query: String, replacementRange: Range<String.Index>), none }`
  - `enum SuggestEngine` mit
    - `static func mode(line: String, cursor: String.Index, dialect: GherkinDialect, isFirstLine: Bool, inDocString: Bool) -> SuggestMode`
    - `static func suggestions(line: String, cursor: String.Index, dialect: GherkinDialect, steps: [String], isFirstLine: Bool, inDocString: Bool, limit: Int = 10) -> [Suggestion]`
  - Konstante `SuggestEngine.defaultLimit = 10`.

Regeln (aus der Spezifikation):
- **keyword**: Zeile ohne Einrückung beginnt mit einem Buchstaben; bis zum Cursor kommt kein vollständiges Schlüsselwort vor (Blockwort + `:` bzw. Stepwort + Leerzeichen). Query = Text von der ersten Nicht-Leerstelle bis zum Cursor (mit Leerzeichen, damit `Scenario O` weiter trifft). Replacement = derselbe Bereich. Insertion = Schlüsselwort + `: ` (Block) bzw. Schlüsselwort + ` ` (Step).
- **step**: Zeile beginnt mit Stepwort + Leerzeichen und Cursor steht dahinter. Query = Text zwischen Stepwort und Cursor, getrimmt. Replacement = von der ersten Nicht-Leerstelle nach dem Stepwort bis zum Zeilenende. Kandidaten = `steps` ohne den exakt (case-insensitive) getippten Text. Leere Query zeigt alle.
- **none**: `inDocString`, Zeile beginnt mit `#`, `@`, `|`, `"""`, ```` ``` ````, Sprachzeile, Blockwortzeile hinter dem `:`, Zeile beginnt mit `*` (Star-Step bekommt keine Vorschläge), oder Cursor steht in der Einrückung / Zeile ist bis zum Cursor leer.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Suggest/SuggestEngineTests.swift`:
```swift
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
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter SuggestEngineTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'SuggestEngine' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Suggest/SuggestEngine.swift`:
```swift
import Foundation

public enum SuggestionKind: Equatable, Sendable {
    case keyword(KeywordCategory)
    case step
}

public struct Suggestion: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let insertion: String
    public let replacementRange: Range<String.Index>
    public let kind: SuggestionKind

    public init(label: String, insertion: String, replacementRange: Range<String.Index>, kind: SuggestionKind) {
        self.label = label
        self.insertion = insertion
        self.replacementRange = replacementRange
        self.kind = kind
        switch kind {
        case .keyword: self.id = "keyword:" + label
        case .step: self.id = "step:" + label
        }
    }
}

public enum SuggestMode: Equatable, Sendable {
    case keyword(query: String, replacementRange: Range<String.Index>)
    case step(query: String, replacementRange: Range<String.Index>)
    case none
}

public enum SuggestEngine {
    public static let defaultLimit = 10

    public static func mode(line: String, cursor: String.Index, dialect: GherkinDialect,
                            isFirstLine: Bool, inDocString: Bool) -> SuggestMode {
        if inDocString { return .none }
        let prefix = line[line.startIndex..<cursor]
        let trimmed = prefix.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmed.first else { return .none }

        if first == "#" || first == "@" || first == "|" || first == "*" { return .none }
        if LineScanner.isDocStringDelimiter(trimmed) { return .none }
        if isFirstLine, LineScanner.languageCode(in: String(line)) != nil { return .none }

        // Blockwort mit Doppelpunkt bereits vollständig → keine Vorschläge
        for entry in dialect.blockKeywords where trimmed.hasPrefix(entry.keyword + ":") {
            return .none
        }

        // Stepwort + Leerzeichen → Step-Modus
        for entry in dialect.stepKeywords where entry.keyword != "*" && trimmed.hasPrefix(entry.keyword + " ") {
            let afterKeyword = trimmed.index(trimmed.startIndex, offsetBy: entry.keyword.count + 1)
            let rest = trimmed[afterKeyword...]
            let queryStart = rest.firstIndex(where: { $0 != " " && $0 != "\t" }) ?? rest.endIndex
            let query = String(rest[queryStart...]).trimmingCharacters(in: .whitespaces)
            let replacementStart = queryStart == rest.endIndex ? cursor : queryStart
            return .step(query: query, replacementRange: replacementStart..<line.endIndex)
        }

        guard first.isLetter else { return .none }
        return .keyword(query: String(trimmed), replacementRange: trimmed.startIndex..<cursor)
    }

    public static func suggestions(line: String, cursor: String.Index, dialect: GherkinDialect,
                                   steps: [String], isFirstLine: Bool, inDocString: Bool,
                                   limit: Int = defaultLimit) -> [Suggestion] {
        switch mode(line: line, cursor: cursor, dialect: dialect, isFirstLine: isFirstLine, inDocString: inDocString) {
        case .none:
            return []

        case let .keyword(query, range):
            let table = Dictionary(dialect.suggestableKeywords.map { ($0.keyword, $0.category) },
                                   uniquingKeysWith: { first, _ in first })
            let ranked = FuzzyMatcher.rank(query: query, candidates: Array(table.keys), limit: limit)
            return ranked.map { keyword in
                let category = table[keyword]!
                let insertion = category.isStep ? keyword + " " : keyword + ": "
                return Suggestion(label: keyword, insertion: insertion, replacementRange: range, kind: .keyword(category))
            }

        case let .step(query, range):
            let candidates = steps.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
            let ranked = FuzzyMatcher.rank(query: query, candidates: candidates, limit: limit)
            return ranked.map { Suggestion(label: $0, insertion: $0, replacementRange: range, kind: .step) }
        }
    }
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test 2>&1 | tail -20`
Expected: alle Tests grün. Falls `typingBSuggestsBackground` wegen der Reihenfolge fehlschlägt: der Test akzeptiert "But" oder "Background" an erster Stelle, beide sind korrekt.

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add SuggestEngine with keyword and step modes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 5: FileNode und Dateibaum

**Files:**
- Create: `Core/Sources/GuerkchenCore/Project/FileNode.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Project/FileNodeTests.swift`

**Interfaces:**
- Consumes: nichts.
- Produces:
  - `struct FileNode: Identifiable, Hashable, Sendable` mit `id: URL`, `url: URL` (standardisiert, ohne Trailing-Slash-Unterschiede), `name: String`, `isDirectory: Bool`, `children: [FileNode]?` (nil bei Dateien, `[]` bei leeren Ordnern), `isFeatureFile: Bool`.
  - `enum FileTreeBuilder` mit `static func build(root: URL) throws -> FileNode` (nur Ordner und `.feature`-Dateien, versteckte Einträge ausgeblendet, Ordner vor Dateien, jeweils lokalisiert alphabetisch) und `static func featureFiles(under root: URL) -> [URL]` (rekursiv, gleiche Filterregeln, sortiert nach Pfad).

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Project/FileNodeTests.swift`:
```swift
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
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter FileNodeTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'FileTreeBuilder' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Project/FileNode.swift`:
```swift
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
    private static let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]

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
            let values = try entry.resourceValues(forKeys: Set(keys))
            let url = entry.standardizedFileURL
            let name = values.name ?? url.lastPathComponent
            if values.isDirectory == true {
                nodes.append(FileNode(url: url, name: name, isDirectory: true, children: try children(of: url)))
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
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test --filter FileNodeTests 2>&1 | tail -20`
Expected: 4 Tests grün. Hinweis: `standardizedFileURL` löst `/var` → `/private/var` auf; der Test vergleicht deshalb beide Seiten standardisiert.

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add FileNode and FileTreeBuilder

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 6: StepIndex

**Files:**
- Create: `Core/Sources/GuerkchenCore/Project/StepIndex.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Project/StepIndexTests.swift`

**Interfaces:**
- Consumes: `LineScanner.dialect(for:)`, `LineScanner.scan`, `FileTreeBuilder.featureFiles(under:)`.
- Produces: `struct StepIndex: Sendable, Equatable` mit
  - `init()` (leer),
  - `mutating func add(text: String)` (Sprache aus Text, alle Step-Zeilen, Text hinter dem Schlüsselwort getrimmt, leere ignoriert),
  - `func steps(for languageCode: String) -> [String]` (sortiert, case-insensitive),
  - `var languages: [String]`,
  - `static func build(root: URL) -> StepIndex` (liest alle `.feature`-Dateien; nicht-UTF-8-Dateien werden übersprungen),
  - `static func build(texts: [String]) -> StepIndex`.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Project/StepIndexTests.swift`:
```swift
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
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter StepIndexTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'StepIndex' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Project/StepIndex.swift`:
```swift
import Foundation

public struct StepIndex: Sendable, Equatable {
    private var table: [String: Set<String>] = [:]

    public init() {}

    public var languages: [String] { table.keys.sorted() }

    public func steps(for languageCode: String) -> [String] {
        (table[languageCode.lowercased()] ?? [])
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public mutating func add(text: String) {
        let dialect = LineScanner.dialect(for: text)
        for line in LineScanner.scan(text, dialect: dialect) {
            guard case let .keyword(category, _, textRange) = line.kind, category.isStep else { continue }
            let step = text[textRange].trimmingCharacters(in: .whitespaces)
            guard !step.isEmpty else { continue }
            table[dialect.code, default: []].insert(step)
        }
    }

    public static func build(texts: [String]) -> StepIndex {
        var index = StepIndex()
        texts.forEach { index.add(text: $0) }
        return index
    }

    public static func build(root: URL) -> StepIndex {
        let texts = FileTreeBuilder.featureFiles(under: root).compactMap { url -> String? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return build(texts: texts)
    }
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test --filter StepIndexTests 2>&1 | tail -20`
Expected: 6 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add StepIndex

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 7: FileOperations

**Files:**
- Create: `Core/Sources/GuerkchenCore/Project/FileOperations.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Project/FileOperationsTests.swift`

**Interfaces:**
- Consumes: nichts.
- Produces:
  - `enum FileOperationError: Error, Equatable, LocalizedError { case emptyName, invalidName(String), alreadyExists(URL) }` mit deutschen `errorDescription`-Texten.
  - `enum FileOperations` mit
    - `static func normalizedFeatureName(_ name: String) -> String` (trimmt, ergänzt `.feature`, wenn die Endung fehlt),
    - `static func createFeatureFile(in directory: URL, name: String) throws -> URL` (Inhalt: `Feature: <Name ohne Endung>\n`),
    - `static func createFolder(in directory: URL, name: String) throws -> URL`,
    - `static func rename(_ url: URL, to newName: String) throws -> URL` (Dateien bekommen `.feature` ergänzt; Ordner nicht; gleicher Name ist ein No-op; vorhandenes Ziel → `alreadyExists`),
    - `static func trash(_ url: URL) throws` (`FileManager.trashItem`).
  - Namen mit `/` oder `:` oder nur Whitespace werden mit `invalidName`/`emptyName` abgelehnt.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Project/FileOperationsTests.swift`:
```swift
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
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter FileOperationsTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'FileOperations' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`Core/Sources/GuerkchenCore/Project/FileOperations.swift`:
```swift
import Foundation

public enum FileOperationError: Error, Equatable, LocalizedError {
    case emptyName
    case invalidName(String)
    case alreadyExists(URL)

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Der Name darf nicht leer sein."
        case .invalidName(let name): return "„\(name)“ ist kein gültiger Name. „/“ und „:“ sind nicht erlaubt."
        case .alreadyExists(let url): return "„\(url.lastPathComponent)“ existiert bereits."
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
        try ensureAbsent(target)
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
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd Core && swift test --filter FileOperationsTests 2>&1 | tail -20`
Expected: 7 Tests grün. Hinweis: `trashItem` funktioniert auch im temporären Ordner ohne Sandbox; falls es in der CI-Umgebung mit einem Berechtigungsfehler scheitert, den Test mit `.disabled("no Trash in CI")` markieren, nicht die Implementierung ändern.

- [ ] **Step 5: Commit**

```bash
git add Core
git commit -m "feat(core): add FileOperations (create, rename, trash)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 8: FolderWatcher und ProjectFolder

**Files:**
- Create: `Core/Sources/GuerkchenCore/Project/FolderWatcher.swift`
- Create: `Core/Sources/GuerkchenCore/Project/ProjectFolder.swift`
- Test: `Core/Tests/GuerkchenCoreTests/Project/ProjectFolderTests.swift`

**Interfaces:**
- Consumes: `FileTreeBuilder.build`, `StepIndex.build(root:)`, `FileOperations.*`.
- Produces:
  - `@MainActor final class FolderWatcher` mit `init(url: URL, latency: TimeInterval = 0.5, onChange: @escaping @MainActor () -> Void)`, `func start()`, `func stop()`; `deinit` stoppt.
  - `@MainActor @Observable public final class ProjectFolder` mit `let rootURL: URL`, `private(set) var tree: FileNode`, `private(set) var stepIndex: StepIndex`, `private(set) var changeCounter: Int` (zählt Ordnerereignisse, damit die UI reagieren kann), `init(rootURL: URL, watch: Bool = true) throws`, `func refresh()`, `func rebuildIndex()`, `func createFeatureFile(in: URL, name: String) throws -> URL`, `func createFolder(in: URL, name: String) throws -> URL`, `func rename(_: URL, to: String) throws -> URL`, `func trash(_: URL) throws`, `func steps(for languageCode: String) -> [String]`.
  - Alle mutierenden Methoden rufen danach `refresh()` auf.

- [ ] **Step 1: Fehlschlagenden Test schreiben**

`Core/Tests/GuerkchenCoreTests/Project/ProjectFolderTests.swift`:
```swift
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
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd Core && swift test --filter ProjectFolderTests 2>&1 | tail -20`
Expected: Compile-Fehler `cannot find 'ProjectFolder' in scope`.

- [ ] **Step 3: FolderWatcher schreiben**

`Core/Sources/GuerkchenCore/Project/FolderWatcher.swift`:
```swift
import Foundation
import CoreServices

/// Beobachtet einen Ordner rekursiv per FSEvents und ruft `onChange` auf dem Main-Thread.
@MainActor
public final class FolderWatcher {
    private let url: URL
    private let latency: TimeInterval
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    public init(url: URL, latency: TimeInterval = 0.5, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.latency = latency
        self.onChange = onChange
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    public func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.onChange() }
        }

        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [url.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency, flags)
        else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
```

Hinweise: Eigene Schreibvorgänge lösen ebenfalls Ereignisse aus; der daraus folgende zusätzliche `refresh()` ist billig und gewollt (so feuert auch der Test). Sollte der Compiler `MainActor.assumeIsolated` innerhalb der C-Closure ablehnen, stattdessen `DispatchQueue.main.async { MainActor.assumeIsolated { watcher.onChange() } }` verwenden. Beschwert sich der Compiler über den Zugriff auf `stream` im `deinit`, den Deinitializer als `isolated deinit` deklarieren (Swift 6.1+).

- [ ] **Step 4: ProjectFolder schreiben**

`Core/Sources/GuerkchenCore/Project/ProjectFolder.swift`:
```swift
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
```

- [ ] **Step 5: Tests laufen lassen**

Run: `cd Core && swift test 2>&1 | tail -30`
Expected: alle Tests grün, inklusive `watcherFiresOnChange` (dauert bis zu 4 s). Falls der Watcher-Test unter `swift test` nie feuert, weil kein Main-RunLoop läuft: `FSEventStreamSetDispatchQueue` braucht keinen RunLoop, aber `Task.sleep` muss den Main-Actor freigeben; das ist mit `async` gegeben. Bleibt er rot, den Test auf `.disabled("FSEvents not delivered under swift test")` setzen und den Watcher manuell in der App prüfen (Task 15).

- [ ] **Step 6: Commit**

```bash
git add Core
git commit -m "feat(core): add FolderWatcher and ProjectFolder

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 9: App-Gerüst mit XcodeGen, Fenster, Menüs und zuletzt geöffneten Projekten

**Files:**
- Create: `project.yml`
- Create: `App/App/GuerkchenApp.swift`
- Create: `App/App/AppState.swift`
- Create: `App/App/RecentProjects.swift`
- Create: `App/UI/ContentView.swift`

**Interfaces:**
- Consumes: `ProjectFolder`, `FileNode` aus GuerkchenCore.
- Produces:
  - `@MainActor @Observable final class RecentProjects` mit `private(set) var urls: [URL]`, `func add(_ url: URL)`, `func remove(_ url: URL)`, `func clear()`. Speichert Security-Scoped Bookmarks unter `UserDefaults`-Key `recentProjectBookmarks`, max. 10, neueste zuerst.
  - `@MainActor @Observable final class AppState` mit `var project: ProjectFolder?`, `var selectedFileURL: URL?`, `var errorMessage: String?`, `let recent: RecentProjects`, `var newFileRequestID: Int` (Zähler, Cmd+N erhöht ihn), `func openFolderDialog()`, `func open(_ url: URL)`, `func closeProject()`, `func requestNewFile()`. Task 11 ergänzt `document` und `select(_:)`.
  - `ContentView` mit `NavigationSplitView`; Sidebar und Detail sind in diesem Task Platzhalter und werden in Task 11/12 ersetzt.

- [ ] **Step 1: project.yml schreiben**

```yaml
name: guerkchen
options:
  bundleIdPrefix: de.fuerstenberg
  deploymentTarget:
    macOS: "15.0"
  createIntermediateGroups: true
  xcodeVersion: "26.0"

packages:
  GuerkchenCore:
    path: Core

targets:
  guerkchen:
    type: application
    platform: macOS
    sources:
      - path: App
    dependencies:
      - package: GuerkchenCore
        product: GuerkchenCore
    info:
      path: Config/Info.plist
      properties:
        CFBundleDisplayName: guerkchen
        CFBundleName: guerkchen
        LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)
        LSApplicationCategoryType: public.app-category.developer-tools
        NSHumanReadableCopyright: "© 2026 René Fürstenberg"
    entitlements:
      path: Config/guerkchen.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.files.user-selected.read-write: true
        com.apple.security.files.bookmarks.app-scope: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.fuerstenberg.guerkchen
        SWIFT_VERSION: "5.0"
        SWIFT_STRICT_CONCURRENCY: minimal
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        DEVELOPMENT_TEAM: ""
        ENABLE_HARDENED_RUNTIME: false
        SWIFT_EMIT_LOC_STRINGS: false
```

Hinweis: `Config/` wird von XcodeGen erzeugt (Info.plist und Entitlements) und liegt außerhalb von `App/`, damit die Dateien nicht als Quellen mitkompiliert werden. `Config/` wird eingecheckt. Die Signatur `-` ist Ad-hoc; damit läuft die sandboxed App lokal ohne Team.

- [ ] **Step 2: RecentProjects schreiben**

`App/App/RecentProjects.swift`:
```swift
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
```

- [ ] **Step 3: AppState schreiben**

`App/App/AppState.swift`:
```swift
import AppKit
import Foundation
import Observation
import GuerkchenCore

@MainActor
@Observable
final class AppState {
    var project: ProjectFolder?
    var selectedFileURL: URL?
    var errorMessage: String?
    var newFileRequestID = 0
    let recent = RecentProjects()

    init() {
        if let last = recent.urls.first, FileManager.default.fileExists(atPath: last.path) {
            open(last)
        }
    }

    func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Projekt öffnen"
        panel.message = "Wähle einen Ordner mit .feature-Dateien."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.open(url) }
        }
    }

    func open(_ url: URL) {
        do {
            project = try ProjectFolder(rootURL: url)
            selectedFileURL = nil
            recent.add(url)
        } catch {
            errorMessage = "Der Ordner „\(url.lastPathComponent)“ konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    func closeProject() {
        project = nil
        selectedFileURL = nil
    }

    func requestNewFile() {
        newFileRequestID += 1
    }
}
```

- [ ] **Step 4: ContentView und App schreiben**

`App/UI/ContentView.swift`:
```swift
import SwiftUI
import GuerkchenCore

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            detail
        }
        .navigationTitle(appState.project?.rootURL.lastPathComponent ?? "guerkchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.openFolderDialog()
                } label: {
                    Label("Ordner öffnen", systemImage: "folder")
                }
            }
        }
        .alert("Fehler", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    @ViewBuilder private var sidebar: some View {
        if let project = appState.project {
            // Platzhalter, wird in Task 12 durch FileTreeView ersetzt
            List(project.tree.children ?? [], id: \.id) { node in
                Label(node.name, systemImage: node.isDirectory ? "folder" : "doc.text")
            }
        } else {
            ContentUnavailableView {
                Label("Kein Projekt", systemImage: "folder.badge.questionmark")
            } description: {
                Text("Öffne einen Ordner mit .feature-Dateien.")
            } actions: {
                Button("Ordner öffnen…") { appState.openFolderDialog() }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        // Platzhalter, wird in Task 11 durch EditorView ersetzt
        ContentUnavailableView("Keine Datei ausgewählt", systemImage: "doc.text",
                               description: Text("Wähle links eine .feature-Datei."))
    }
}
```

`App/App/GuerkchenApp.swift`:
```swift
import SwiftUI

@main
struct GuerkchenApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("guerkchen", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neue Feature-Datei…") { appState.requestNewFile() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(appState.project == nil)
                Divider()
                Button("Ordner öffnen…") { appState.openFolderDialog() }
                    .keyboardShortcut("o", modifiers: .command)
                Menu("Zuletzt geöffnet") {
                    ForEach(appState.recent.urls, id: \.path) { url in
                        Button(url.lastPathComponent) { appState.open(url) }
                    }
                    if !appState.recent.urls.isEmpty {
                        Divider()
                        Button("Liste löschen") { appState.recent.clear() }
                    }
                }
                Button("Projekt schließen") { appState.closeProject() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(appState.project == nil)
            }
        }
    }
}
```

- [ ] **Step 5: Projekt erzeugen und bauen**

Run:
```bash
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. Bei Fehlern in `project.yml` die XcodeGen-Fehlermeldung lesen; bei Signaturfehlern prüfen, dass `CODE_SIGN_IDENTITY: "-"` und `CODE_SIGN_STYLE: Manual` gesetzt sind.

- [ ] **Step 6: App starten und manuell prüfen**

Run: `open build/DerivedData/Build/Products/Debug/guerkchen.app`
Prüfen: Fenster erscheint mit „Kein Projekt“. Cmd+O öffnet den Ordnerdialog. Nach Auswahl eines Ordners erscheint die Liste seiner Einträge. App beenden und neu starten: derselbe Ordner ist wieder offen. Menü „Ablage → Zuletzt geöffnet“ zeigt ihn.

- [ ] **Step 7: Commit**

```bash
git add project.yml Config App
git commit -m "feat(app): scaffold macOS app with XcodeGen, folder open and recents

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 10: Farbschema und Einstellungsfenster

**Files:**
- Create: `App/UI/Theme/HighlightCategory.swift`
- Create: `App/UI/Theme/NSColor+Hex.swift`
- Create: `App/UI/Theme/ColorSettings.swift`
- Create: `App/UI/Settings/SettingsView.swift`
- Modify: `App/App/GuerkchenApp.swift` (Settings-Szene, Environment)

**Interfaces:**
- Consumes: `KeywordCategory`, `LineKind` aus GuerkchenCore.
- Produces:
  - `enum HighlightCategory: String, CaseIterable, Identifiable` mit Fällen `featureRule, background, scenario, step, comment, tag, table, docString`, `title: String`, `defaultHex: String`, `init?(keyword: KeywordCategory)`, `static func forLine(_ kind: LineKind) -> HighlightCategory?`.
  - `extension NSColor { convenience init?(hex: String); var hexString: String }`.
  - `typealias HighlightPalette = [HighlightCategory: String]`.
  - `@MainActor @Observable final class ColorSettings` mit `private(set) var palette: HighlightPalette`, `func color(for: HighlightCategory) -> NSColor`, `func setColor(_: NSColor, for: HighlightCategory)`, `func reset()`, `func binding(for: HighlightCategory) -> Binding<Color>`.
  - `SettingsView`.

- [ ] **Step 1: HighlightCategory schreiben**

`App/UI/Theme/HighlightCategory.swift`:
```swift
import Foundation
import GuerkchenCore

enum HighlightCategory: String, CaseIterable, Identifiable {
    case featureRule, background, scenario, step, comment, tag, table, docString

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featureRule: return "Feature / Rule"
        case .background: return "Background"
        case .scenario: return "Scenario / Outline / Examples"
        case .step: return "Given / When / Then / And / But"
        case .comment: return "Kommentare"
        case .tag: return "Tags"
        case .table: return "Tabellen"
        case .docString: return "Doc-Strings"
        }
    }

    var defaultHex: String {
        switch self {
        case .featureRule: return "#AF52DE"
        case .background: return "#00A99D"
        case .scenario: return "#007AFF"
        case .step: return "#34C759"
        case .comment: return "#8E8E93"
        case .tag: return "#FF9500"
        case .table: return "#A2845E"
        case .docString: return "#FF2D55"
        }
    }

    init?(keyword: KeywordCategory) {
        switch keyword {
        case .feature, .rule: self = .featureRule
        case .background: self = .background
        case .scenario, .scenarioOutline, .examples: self = .scenario
        case .given, .when, .then, .and, .but: self = .step
        }
    }

    static func forLine(_ kind: LineKind) -> HighlightCategory? {
        switch kind {
        case .comment, .languageLine: return .comment
        case .tag: return .tag
        case .tableRow: return .table
        case .docStringDelimiter, .docStringContent: return .docString
        case .keyword(let category, _, _): return HighlightCategory(keyword: category)
        case .blank, .other: return nil
        }
    }
}
```

- [ ] **Step 2: NSColor+Hex schreiben**

`App/UI/Theme/NSColor+Hex.swift`:
```swift
import AppKit

extension NSColor {
    /// "#RRGGBB" oder "RRGGBB"
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

- [ ] **Step 3: ColorSettings schreiben**

`App/UI/Theme/ColorSettings.swift`:
```swift
import AppKit
import Observation
import SwiftUI

typealias HighlightPalette = [HighlightCategory: String]

@MainActor
@Observable
final class ColorSettings {
    private static let keyPrefix = "highlightColor."

    private(set) var palette: HighlightPalette = [:]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func color(for category: HighlightCategory) -> NSColor {
        NSColor(hex: palette[category] ?? category.defaultHex) ?? .textColor
    }

    func setColor(_ color: NSColor, for category: HighlightCategory) {
        let hex = color.hexString
        palette[category] = hex
        defaults.set(hex, forKey: Self.keyPrefix + category.rawValue)
    }

    func reset() {
        for category in HighlightCategory.allCases {
            defaults.removeObject(forKey: Self.keyPrefix + category.rawValue)
        }
        load()
    }

    func binding(for category: HighlightCategory) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: self.color(for: category)) },
            set: { self.setColor(NSColor($0), for: category) })
    }

    private func load() {
        var result: HighlightPalette = [:]
        for category in HighlightCategory.allCases {
            if let stored = defaults.string(forKey: Self.keyPrefix + category.rawValue), NSColor(hex: stored) != nil {
                result[category] = stored
            } else {
                result[category] = category.defaultHex
            }
        }
        palette = result
    }
}
```

- [ ] **Step 4: SettingsView schreiben**

`App/UI/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(ColorSettings.self) private var colors

    var body: some View {
        Form {
            Section("Farben der Schlüsselwörter") {
                ForEach(HighlightCategory.allCases) { category in
                    ColorPicker(category.title, selection: colors.binding(for: category), supportsOpacity: false)
                }
            }
            Section {
                Button("Auf Standardfarben zurücksetzen") { colors.reset() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.bottom)
    }
}
```

- [ ] **Step 5: GuerkchenApp erweitern**

In `App/App/GuerkchenApp.swift`:
- Nach `@State private var appState = AppState()` einfügen: `@State private var colors = ColorSettings()`.
- In `Window { ... }` die Zeile `.environment(appState)` ergänzen um `.environment(colors)` direkt darunter.
- Nach dem schließenden `}` von `.commands { ... }` eine zweite Szene ergänzen:
```swift
        Settings {
            SettingsView()
                .environment(colors)
        }
```

- [ ] **Step 6: Bauen und prüfen**

Run:
```bash
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -5
open build/DerivedData/Build/Products/Debug/guerkchen.app
```
Expected: `** BUILD SUCCEEDED **`. Cmd+, öffnet die Einstellungen mit acht Farbfeldern und Reset-Knopf. Eine geänderte Farbe bleibt nach Neustart erhalten (`defaults read de.fuerstenberg.guerkchen` zeigt `highlightColor.step`).

- [ ] **Step 7: Commit**

```bash
git add App
git commit -m "feat(app): add highlight color settings

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 11: Editor mit Dokument, Autosave und Syntaxfärbung

**Files:**
- Create: `App/UI/Editor/EditorDocument.swift`
- Create: `App/UI/Editor/SyntaxHighlighter.swift`
- Create: `App/UI/Editor/GherkinTextView.swift`
- Create: `App/UI/Editor/EditorView.swift`
- Modify: `App/App/AppState.swift` (`document`, `select(_:)`, `handleProjectChange()`, Speichern beim Beenden)
- Modify: `App/UI/ContentView.swift` (Detail durch `EditorView` ersetzen, Auswahl verdrahten)

**Interfaces:**
- Consumes: `LineScanner`, `HighlightCategory.forLine`, `HighlightPalette`, `ColorSettings.palette`, `ProjectFolder.rebuildIndex()`, `ProjectFolder.steps(for:)`, `ProjectFolder.changeCounter`.
- Produces:
  - `@MainActor @Observable final class EditorDocument` mit `let url: URL`, `private(set) var text: String`, `private(set) var isDirty: Bool`, `private(set) var loadError: String?`, `private(set) var saveError: String?`, `var onSaved: (() -> Void)?`, `init(url: URL)`, `func updateText(_:)` (markiert dirty, plant Autosave nach 1 s), `func saveNow()`, `func reloadIfClean()`.
  - `enum SyntaxHighlighter { @MainActor static func highlight(storage: NSTextStorage, palette: HighlightPalette, font: NSFont) }`.
  - `struct GherkinTextView: NSViewRepresentable` mit `init(document: EditorDocument, palette: HighlightPalette, stepsProvider: @escaping (String) -> [String])` und `static let font: NSFont`. Der `Coordinator` besitzt `var suggest: SuggestController?` (in Task 13 gesetzt; in diesem Task ein leerer Platzhaltertyp, siehe Step 4).
  - `struct EditorView: View`.
  - `AppState.document: EditorDocument?`, `AppState.select(_ url: URL?)`, `AppState.handleProjectChange()`.

- [ ] **Step 1: EditorDocument schreiben**

`App/UI/Editor/EditorDocument.swift`:
```swift
import Foundation
import Observation

@MainActor
@Observable
final class EditorDocument {
    let url: URL
    private(set) var text: String = ""
    private(set) var isDirty = false
    private(set) var loadError: String?
    private(set) var saveError: String?
    @ObservationIgnored var onSaved: (() -> Void)?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?

    static let autosaveDelay: Duration = .seconds(1)

    init(url: URL) {
        self.url = url
        load()
    }

    func updateText(_ newText: String) {
        guard newText != text else { return }
        text = newText
        isDirty = true
        scheduleAutosave()
    }

    func saveNow() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard isDirty, loadError == nil else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDirty = false
            saveError = nil
            onSaved?()
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Lädt die Datei neu, wenn der Editor keine ungesicherten Änderungen hat.
    func reloadIfClean() {
        guard !isDirty else { return }
        guard let disk = readFromDisk() else { return }
        if disk != text { text = disk }
    }

    private func load() {
        if let content = readFromDisk() {
            text = content
            loadError = nil
        } else {
            text = ""
            loadError = "Die Datei „\(url.lastPathComponent)“ ist kein gültiges UTF-8 oder konnte nicht gelesen werden."
        }
    }

    private func readFromDisk() -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
}
```

- [ ] **Step 2: SyntaxHighlighter schreiben**

`App/UI/Editor/SyntaxHighlighter.swift`:
```swift
import AppKit
import GuerkchenCore

enum SyntaxHighlighter {
    @MainActor
    static func highlight(storage: NSTextStorage, palette: HighlightPalette, font: NSFont) {
        let text = storage.string
        let dialect = LineScanner.dialect(for: text)
        let full = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        storage.addAttributes([.font: font, .foregroundColor: NSColor.textColor], range: full)
        for line in LineScanner.scan(text, dialect: dialect) {
            guard let category = HighlightCategory.forLine(line.kind) else { continue }
            let color = NSColor(hex: palette[category] ?? category.defaultHex) ?? .textColor
            let range: Range<String.Index>
            if case let .keyword(_, keywordRange, _) = line.kind {
                range = keywordRange
            } else {
                range = line.range
            }
            storage.addAttribute(.foregroundColor, value: color, range: NSRange(range, in: text))
        }
        storage.endEditing()
    }
}
```

- [ ] **Step 3: GherkinTextView schreiben**

`App/UI/Editor/GherkinTextView.swift`:
```swift
import AppKit
import SwiftUI
import GuerkchenCore

struct GherkinTextView: NSViewRepresentable {
    let document: EditorDocument
    let palette: HighlightPalette
    let stepsProvider: (String) -> [String]

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = Self.font
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        context.coordinator.textView = textView
        context.coordinator.suggest = SuggestController(textView: textView)
        context.coordinator.update(document: document, palette: palette, stepsProvider: stepsProvider)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(document: document, palette: palette, stepsProvider: stepsProvider)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var suggest: SuggestController?
        private var document: EditorDocument?
        private var palette: HighlightPalette = [:]
        private var isApplying = false

        func update(document: EditorDocument, palette: HighlightPalette, stepsProvider: @escaping (String) -> [String]) {
            suggest?.stepsProvider = stepsProvider
            guard let textView else { return }
            let documentChanged = document !== self.document
            let paletteChanged = palette != self.palette
            self.document = document
            self.palette = palette

            if documentChanged || textView.string != document.text {
                isApplying = true
                textView.string = document.text
                if documentChanged { textView.setSelectedRange(NSRange(location: 0, length: 0)) }
                isApplying = false
                suggest?.hide()
                rehighlight()
            } else if paletteChanged {
                rehighlight()
            }
        }

        func rehighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            SyntaxHighlighter.highlight(storage: storage, palette: palette, font: GherkinTextView.font)
            textView.typingAttributes = [.font: GherkinTextView.font, .foregroundColor: NSColor.textColor]
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView, let document else { return }
            document.updateText(textView.string)
            rehighlight()
            suggest?.textDidChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplying else { return }
            suggest?.selectionDidChange()
        }

        func textDidEndEditing(_ notification: Notification) {
            suggest?.hide()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            suggest?.handle(commandSelector) ?? false
        }
    }
}
```

- [ ] **Step 4: Platzhalter für SuggestController anlegen**

Damit dieser Task baut, bevor Task 13 den echten Controller liefert, `App/UI/Editor/SuggestController.swift` mit dieser Minimalfassung anlegen. Task 13 ersetzt die Datei vollständig.
```swift
import AppKit

@MainActor
final class SuggestController {
    var stepsProvider: (String) -> [String] = { _ in [] }
    init(textView: NSTextView) {}
    func textDidChange() {}
    func selectionDidChange() {}
    func hide() {}
    func handle(_ selector: Selector) -> Bool { false }
}
```

- [ ] **Step 5: EditorView schreiben**

`App/UI/Editor/EditorView.swift`:
```swift
import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(ColorSettings.self) private var colors

    var body: some View {
        if let document = appState.document {
            VStack(spacing: 0) {
                if let loadError = document.loadError {
                    ContentUnavailableView("Datei kann nicht angezeigt werden", systemImage: "doc.badge.exclamationmark",
                                           description: Text(loadError))
                } else {
                    GherkinTextView(document: document, palette: colors.palette) { code in
                        appState.project?.steps(for: code) ?? []
                    }
                }
                if let saveError = document.saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle")
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.2))
                }
            }
        } else {
            ContentUnavailableView("Keine Datei ausgewählt", systemImage: "doc.text",
                                   description: Text("Wähle links eine .feature-Datei."))
        }
    }
}
```

- [ ] **Step 6: AppState erweitern**

In `App/App/AppState.swift`:
- Nach `var selectedFileURL: URL?` einfügen: `var document: EditorDocument?`.
- `init()` ersetzen durch:
```swift
    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.document?.saveNow() }
        }
        if let last = recent.urls.first, FileManager.default.fileExists(atPath: last.path) {
            open(last)
        }
    }
```
- `open(_:)` und `closeProject()` vollständig ersetzen durch:
```swift
    func open(_ url: URL) {
        document?.saveNow()
        do {
            project = try ProjectFolder(rootURL: url)
            selectedFileURL = nil
            document = nil
            recent.add(url)
        } catch {
            errorMessage = "Der Ordner „\(url.lastPathComponent)“ konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    func closeProject() {
        document?.saveNow()
        project = nil
        selectedFileURL = nil
        document = nil
    }
```
- Neue Methoden ergänzen:
```swift
    /// Wechselt die geöffnete Datei. Speichert die vorherige.
    func select(_ url: URL?) {
        guard url != document?.url else { return }
        document?.saveNow()
        selectedFileURL = url
        guard let url else { document = nil; return }
        let doc = EditorDocument(url: url)
        doc.onSaved = { [weak self] in self?.project?.rebuildIndex() }
        document = doc
    }

    /// Reaktion auf Ordnerereignisse: verschwundene Datei abwählen, sonst sauberes Dokument neu laden.
    func handleProjectChange() {
        guard let document else { return }
        if !FileManager.default.fileExists(atPath: document.url.path) {
            select(nil)
        } else {
            document.reloadIfClean()
        }
    }
```

- [ ] **Step 7: ContentView verdrahten**

In `App/UI/ContentView.swift`:
- Die Platzhalter-`List` in `sidebar` ersetzen durch:
```swift
            List(project.tree.children ?? [], id: \.id, children: \.children, selection: $appState.selectedFileURL) { node in
                Label(node.name, systemImage: node.isDirectory ? "folder" : "doc.text")
                    .tag(node.url)
                    .selectionDisabled(node.isDirectory)
            }
```
- `detail` ersetzen durch `EditorView()`.
- Nach `.navigationTitle(...)` ergänzen:
```swift
        .onChange(of: appState.selectedFileURL) { _, newValue in appState.select(newValue) }
        .onChange(of: appState.project?.changeCounter) { _, _ in appState.handleProjectChange() }
```

- [ ] **Step 8: Bauen und manuell prüfen**

Run:
```bash
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -5
open build/DerivedData/Build/Products/Debug/guerkchen.app
```
Prüfen mit einem Ordner, der eine Datei mit folgendem Inhalt enthält:
```
# language: de
@wichtig
Funktionalität: Anmeldung
  Szenario: Login
    Gegeben sei ein Nutzer
    Wenn er sich anmeldet
    # Kommentar
    Dann sieht er
      | Spalte |
    """
    Doc
    """
```
- Datei anklicken: Inhalt erscheint, Schlüsselwörter farbig, Kommentar grau, Tag orange, Tabelle braun, Doc-String pink.
- Ein Zeichen tippen, eine Sekunde warten, Datei in einem Terminal mit `cat` prüfen: Änderung ist gespeichert.
- Farbe in den Einstellungen ändern: Editor färbt sofort um.
- Datei im Terminal ändern (`echo "Dann extern" >> datei.feature`) ohne ungesicherte Änderungen im Editor: Editor lädt neu.
- Datei im Terminal löschen: Editor zeigt „Keine Datei ausgewählt“.

- [ ] **Step 9: Commit**

```bash
git add App
git commit -m "feat(app): add editor with autosave and syntax highlighting

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 12: Dateibaum mit Anlegen, Umbenennen, Löschen

**Files:**
- Create: `App/UI/Sidebar/NameSheet.swift`
- Create: `App/UI/Sidebar/FileTreeView.swift`
- Modify: `App/UI/ContentView.swift` (Sidebar-Liste durch `FileTreeView` ersetzen)

**Interfaces:**
- Consumes: `AppState.project`, `.selectedFileURL`, `.newFileRequestID`, `.errorMessage`, `ProjectFolder.createFeatureFile/createFolder/rename/trash`, `FileNode`.
- Produces: `struct NameSheet: View` mit `init(title: String, prompt: String, initialValue: String, onCommit: @escaping (String) -> Void)`; `struct FileTreeView: View`.

- [ ] **Step 1: NameSheet schreiben**

`App/UI/Sidebar/NameSheet.swift`:
```swift
import SwiftUI

/// Kleines Sheet zur Namenseingabe für Anlegen und Umbenennen.
struct NameSheet: View {
    let title: String
    let prompt: String
    let initialValue: String
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField(prompt, text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("OK", action: commit).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            name = initialValue
            focused = true
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        dismiss()
        onCommit(trimmed)
    }
}
```

- [ ] **Step 2: FileTreeView schreiben**

`App/UI/Sidebar/FileTreeView.swift`:
```swift
import SwiftUI
import GuerkchenCore

struct FileTreeView: View {
    @Environment(AppState.self) private var appState

    private enum SheetKind: Identifiable {
        case newFile(in: URL)
        case newFolder(in: URL)
        case rename(URL, isDirectory: Bool)

        var id: String {
            switch self {
            case .newFile(let dir): return "newFile:\(dir.path)"
            case .newFolder(let dir): return "newFolder:\(dir.path)"
            case .rename(let url, _): return "rename:\(url.path)"
            }
        }
    }

    @State private var sheet: SheetKind?
    @State private var rootExpanded = true

    var body: some View {
        @Bindable var appState = appState
        List(selection: $appState.selectedFileURL) {
            if let project = appState.project {
                DisclosureGroup(isExpanded: $rootExpanded) {
                    OutlineGroup(project.tree.children ?? [], id: \.id, children: \.children) { node in
                        row(node)
                    }
                } label: {
                    Label(project.tree.name, systemImage: "folder.fill")
                        .contextMenu { directoryMenu(for: project.rootURL, isRoot: true) }
                }
                .selectionDisabled()
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appState.newFileRequestID) { _, _ in
            guard let project = appState.project else { return }
            sheet = .newFile(in: directoryForNewItems(project: project))
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .newFile(let dir):
                NameSheet(title: "Neue Feature-Datei", prompt: "Name (ohne .feature)", initialValue: "") { name in
                    perform { try appState.project?.createFeatureFile(in: dir, name: name) }
                }
            case .newFolder(let dir):
                NameSheet(title: "Neuer Ordner", prompt: "Ordnername", initialValue: "") { name in
                    perform { try appState.project?.createFolder(in: dir, name: name) }
                }
            case .rename(let url, _):
                NameSheet(title: "Umbenennen", prompt: "Neuer Name", initialValue: url.lastPathComponent) { name in
                    let wasSelected = appState.selectedFileURL == url
                    perform {
                        let renamed = try appState.project?.rename(url, to: name)
                        if wasSelected, let renamed { appState.select(renamed) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func row(_ node: FileNode) -> some View {
        if node.isDirectory {
            Label(node.name, systemImage: "folder")
                .selectionDisabled()
                .contextMenu { directoryMenu(for: node.url, isRoot: false) }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
                .contextMenu { fileMenu(for: node.url) }
        }
    }

    @ViewBuilder private func directoryMenu(for url: URL, isRoot: Bool) -> some View {
        Button("Neue Feature-Datei…") { sheet = .newFile(in: url) }
        Button("Neuer Ordner…") { sheet = .newFolder(in: url) }
        if !isRoot {
            Divider()
            Button("Umbenennen…") { sheet = .rename(url, isDirectory: true) }
            Button("In den Papierkorb legen") { trash(url) }
        }
    }

    @ViewBuilder private func fileMenu(for url: URL) -> some View {
        Button("Neue Feature-Datei…") { sheet = .newFile(in: url.deletingLastPathComponent()) }
        Button("Neuer Ordner…") { sheet = .newFolder(in: url.deletingLastPathComponent()) }
        Divider()
        Button("Umbenennen…") { sheet = .rename(url, isDirectory: false) }
        Button("In den Papierkorb legen") { trash(url) }
    }

    /// Cmd+N legt neben der ausgewählten Datei an, sonst im Projektordner.
    private func directoryForNewItems(project: ProjectFolder) -> URL {
        appState.selectedFileURL?.deletingLastPathComponent() ?? project.rootURL
    }

    private func trash(_ url: URL) {
        let affectsSelection = appState.selectedFileURL.map { $0.path.hasPrefix(url.path) } ?? false
        if affectsSelection { appState.select(nil) }
        perform { try appState.project?.trash(url) }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { appState.errorMessage = error.localizedDescription }
    }
}
```

- [ ] **Step 3: ContentView anpassen**

In `App/UI/ContentView.swift` den `if let project = appState.project { List(...) }`-Zweig in `sidebar` ersetzen durch:
```swift
        if appState.project != nil {
            FileTreeView()
        } else {
```
(Der `else`-Zweig mit `ContentUnavailableView` bleibt.)

- [ ] **Step 4: Bauen und manuell prüfen**

Run:
```bash
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -5
open build/DerivedData/Build/Products/Debug/guerkchen.app
```
Prüfen:
- Rechtsklick auf den Projektordner → „Neue Feature-Datei…“ → Name „checkout“ → `checkout.feature` erscheint im Baum, Inhalt `Feature: checkout`.
- Cmd+N legt eine Datei neben der ausgewählten Datei an.
- „Neuer Ordner…“ legt einen Ordner an; Rechtsklick darauf bietet Umbenennen und Papierkorb.
- Umbenennen der geöffneten Datei: Editor bleibt auf der umbenannten Datei.
- Umbenennen auf einen bestehenden Namen: Fehlerdialog „existiert bereits“.
- Papierkorb: Datei verschwindet aus dem Baum und liegt im Finder-Papierkorb.
- Ordner mit `README.md` und `.git`: beide sind nicht sichtbar.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): add file tree with create, rename and trash

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 13: Suggest-Dropdown

**Files:**
- Create: `App/UI/Editor/SuggestPanel.swift`
- Replace: `App/UI/Editor/SuggestController.swift` (Platzhalter aus Task 11 vollständig ersetzen)

**Interfaces:**
- Consumes: `SuggestEngine.suggestions`, `Suggestion`, `LineScanner.dialect(for:)`, `LineScanner.scan`, `GherkinTextView.Coordinator` ruft `textDidChange()`, `selectionDidChange()`, `hide()`, `handle(_:)`, setzt `stepsProvider`.
- Produces:
  - `@MainActor final class SuggestPanel: NSPanel` mit `var onPick: ((Int) -> Void)?`, `var selectedSuggestion: Suggestion?`, `func show(_ suggestions: [Suggestion], below cursorRect: NSRect, in window: NSWindow)`, `func hide()`, `func selectNext()`, `func selectPrevious()`.
  - `struct SuggestListView: View` mit `static let rowHeight: CGFloat = 24`.
  - `@MainActor final class SuggestController` mit `init(textView: NSTextView)`, `var stepsProvider: (String) -> [String]`, `func textDidChange()`, `func selectionDidChange()`, `func hide()`, `func handle(_ selector: Selector) -> Bool`.

- [ ] **Step 1: SuggestPanel schreiben**

`App/UI/Editor/SuggestPanel.swift`:
```swift
import AppKit
import SwiftUI
import GuerkchenCore

struct SuggestListView: View {
    static let rowHeight: CGFloat = 24

    let suggestions: [Suggestion]
    let selectedIndex: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: 8) {
                    Image(systemName: icon(for: suggestion.kind))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(suggestion.label)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: Self.rowHeight)
                .background(index == selectedIndex ? Color.accentColor.opacity(0.25) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
                .onTapGesture { onPick(index) }
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
    }

    private func icon(for kind: SuggestionKind) -> String {
        switch kind {
        case .keyword: return "textformat"
        case .step: return "text.line.first.and.arrowtriangle.forward"
        }
    }
}

@MainActor
final class SuggestPanel: NSPanel {
    static let width: CGFloat = 380

    var onPick: ((Int) -> Void)?
    private(set) var suggestions: [Suggestion] = []
    private(set) var selectedIndex = 0
    private let hosting: NSHostingView<SuggestListView>

    var selectedSuggestion: Suggestion? {
        suggestions.indices.contains(selectedIndex) ? suggestions[selectedIndex] : nil
    }

    init() {
        hosting = NSHostingView(rootView: SuggestListView(suggestions: [], selectedIndex: 0, onPick: { _ in }))
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = true
        isReleasedWhenClosed = false
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ suggestions: [Suggestion], below cursorRect: NSRect, in window: NSWindow) {
        self.suggestions = suggestions
        selectedIndex = 0
        render()

        let height = CGFloat(suggestions.count) * SuggestListView.rowHeight + 8
        var origin = NSPoint(x: cursorRect.minX, y: cursorRect.minY - height - 2)
        if let screen = window.screen {
            let visible = screen.visibleFrame
            if origin.y < visible.minY { origin.y = cursorRect.maxY + 2 }
            if origin.x + Self.width > visible.maxX { origin.x = visible.maxX - Self.width }
        }
        setFrame(NSRect(origin: origin, size: NSSize(width: Self.width, height: height)), display: true)
        if parent == nil { window.addChildWindow(self, ordered: .above) }
        orderFront(nil)
    }

    func hide() {
        guard isVisible else { return }
        parent?.removeChildWindow(self)
        orderOut(nil)
    }

    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        render()
    }

    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        render()
    }

    private func render() {
        hosting.rootView = SuggestListView(suggestions: suggestions, selectedIndex: selectedIndex) { [weak self] index in
            self?.selectedIndex = index
            self?.onPick?(index)
        }
    }
}
```

- [ ] **Step 2: SuggestController schreiben (ersetzt den Platzhalter vollständig)**

`App/UI/Editor/SuggestController.swift`:
```swift
import AppKit
import GuerkchenCore

/// Verbindet NSTextView, SuggestEngine und SuggestPanel.
@MainActor
final class SuggestController {
    var stepsProvider: (String) -> [String] = { _ in [] }

    private weak var textView: NSTextView?
    private let panel = SuggestPanel()
    private var suppressNextChange = false
    /// Zeile und Zeilenanfang (UTF-16-Offset im Gesamttext), für die das Panel gerade gilt.
    private var currentLine: String = ""
    private var currentLineLocation = 0

    init(textView: NSTextView) {
        self.textView = textView
        panel.onPick = { [weak self] _ in self?.accept() }
    }

    func textDidChange() {
        if suppressNextChange {
            suppressNextChange = false
            hide()
            return
        }
        refresh()
    }

    func selectionDidChange() {
        guard panel.isVisible, let textView else { return }
        let selection = textView.selectedRange()
        let lineRange = (textView.string as NSString).lineRange(for: NSRange(location: selection.location, length: 0))
        if selection.length > 0 || lineRange.location != currentLineLocation { hide() }
    }

    func hide() {
        panel.hide()
    }

    /// Fängt Tasten ab, solange das Panel sichtbar ist. Escape wird immer geschluckt,
    /// damit NSTextView nicht seine eigene Wortvervollständigung öffnet.
    func handle(_ selector: Selector) -> Bool {
        if selector == #selector(NSResponder.complete(_:)) { return true }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            hide()
            return true
        }
        guard panel.isVisible else { return false }
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            panel.selectPrevious()
            return true
        case #selector(NSResponder.moveDown(_:)):
            panel.selectNext()
            return true
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
            accept()
            return true
        default:
            return false
        }
    }

    // MARK: - Private

    private func refresh() {
        guard let textView, let window = textView.window else { hide(); return }
        let text = textView.string
        let selection = textView.selectedRange()
        guard selection.length == 0 else { hide(); return }

        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selection.location, length: 0))
        var line = nsText.substring(with: lineRange)
        while line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }

        let cursorOffset = selection.location - lineRange.location
        guard cursorOffset >= 0, cursorOffset <= line.utf16.count else { hide(); return }
        let cursor = String.Index(utf16Offset: cursorOffset, in: line)

        let dialect = LineScanner.dialect(for: text)
        let suggestions = SuggestEngine.suggestions(
            line: line, cursor: cursor, dialect: dialect,
            steps: stepsProvider(dialect.code),
            isFirstLine: lineRange.location == 0,
            inDocString: Self.isInsideDocString(text: text, lineLocation: lineRange.location, dialect: dialect))

        guard !suggestions.isEmpty else { hide(); return }
        currentLine = line
        currentLineLocation = lineRange.location

        let cursorRect = textView.firstRect(forCharacterRange: NSRange(location: selection.location, length: 0), actualRange: nil)
        panel.show(suggestions, below: cursorRect, in: window)
    }

    /// Ungerade Anzahl Doc-String-Begrenzer vor dieser Zeile → wir sind in einem Doc-String.
    private static func isInsideDocString(text: String, lineLocation: Int, dialect: GherkinDialect) -> Bool {
        var delimiters = 0
        for scanned in LineScanner.scan(text, dialect: dialect) {
            guard scanned.range.lowerBound.utf16Offset(in: text) < lineLocation else { break }
            if scanned.kind == .docStringDelimiter { delimiters += 1 }
        }
        return delimiters % 2 == 1
    }

    private func accept() {
        guard let textView, let suggestion = panel.selectedSuggestion else { hide(); return }
        let start = currentLineLocation + suggestion.replacementRange.lowerBound.utf16Offset(in: currentLine)
        let end = currentLineLocation + suggestion.replacementRange.upperBound.utf16Offset(in: currentLine)
        let range = NSRange(location: start, length: end - start)

        suppressNextChange = true
        if textView.shouldChangeText(in: range, replacementString: suggestion.insertion) {
            textView.insertText(suggestion.insertion, replacementRange: range)
        }
        suppressNextChange = false
        hide()
    }
}
```

Hinweis zu `insertText(_:replacementRange:)`: Das ist die `NSTextInputClient`-Methode; sie läuft über Undo und ruft intern `didChangeText()`, wodurch `textDidChange` synchron ausgelöst wird. Deshalb wird `suppressNextChange` davor gesetzt und danach zurückgesetzt. Kein zusätzlicher `didChangeText()`-Aufruf, sonst öffnet sich das Panel sofort wieder.

- [ ] **Step 3: Bauen und manuell prüfen**

Run:
```bash
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -5
open build/DerivedData/Build/Products/Debug/guerkchen.app
```
Prüfen in einer englischen Datei eines Projekts, das anderswo die Zeile `Given a user is logged in` enthält:
- Leere Zeile, `g` tippen → Dropdown mit „Given“ unter dem Cursor. Enter → Zeile lautet `Given `, Dropdown ist zu.
- `a u` tippen → Dropdown mit „a user is logged in“. Tab → Zeile ist vollständig.
- Neue Zeile, `sc` → „Scenario“ und „Scenario Outline“; Pfeil runter wählt „Scenario Outline“, Enter fügt `Scenario Outline: ` ein.
- `b` → „But“ und „Background“ (Reihenfolge egal).
- Escape schließt das Dropdown; erneutes Tippen öffnet es wieder.
- In einer Kommentarzeile (`# gi`) erscheint nichts; zwischen `"""` erscheint nichts.
- In einer deutschen Datei (`# language: de`) erscheinen deutsche Schlüsselwörter und nur deutsche Steps.
- Mausklick auf einen Eintrag übernimmt ihn.
- Fenster deaktivieren (Cmd+Tab): Dropdown verschwindet.

- [ ] **Step 4: Commit**

```bash
git add App
git commit -m "feat(app): add suggest dropdown for keywords and steps

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

### Task 14: Beispielprojekt und Gesamtabnahme

**Files:**
- Create: `Examples/demo-project/login.feature`
- Create: `Examples/demo-project/checkout.feature`
- Create: `Examples/demo-project/anmeldung.feature`

**Interfaces:**
- Consumes: die fertige App.
- Produces: ein Beispielprojekt für manuelle Tests und als Vorlage für den Nutzer.

- [ ] **Step 1: Beispieldateien schreiben**

`Examples/demo-project/login.feature`:
```gherkin
@auth
Feature: Login
  As a registered user
  I want to log in with my e-mail address
  So that I can see my personal dashboard

  Background:
    Given a user exists
    And a user is logged out

  Scenario: Successful login
    Given a user is on the login page
    When the user enters valid credentials
    And the user clicks login
    Then the user sees the dashboard

  Scenario Outline: Failed login
    Given a user is on the login page
    When the user enters "<email>" and "<password>"
    Then the user sees the error "<message>"

    Examples:
      | email          | password | message              |
      | wrong@test.de  | secret   | Unknown user         |
      | user@test.de   | wrong    | Wrong password       |
```

`Examples/demo-project/checkout.feature`:
```gherkin
Feature: Checkout
  As a shopper
  I want to pay for the items in my cart
  So that the order is placed

  Scenario: Pay with credit card
    Given a user is logged in
    And the cart is not empty
    When the user chooses credit card
    And the user confirms the order
    Then the order is placed
    And the user receives a confirmation e-mail with the text
      """
      Thank you for your order.
      """
```

`Examples/demo-project/anmeldung.feature`:
```gherkin
# language: de
Funktionalität: Anmeldung
  Als registrierter Nutzer
  möchte ich mich anmelden können,
  damit ich mein persönliches Dashboard sehe

  Grundlage:
    Gegeben sei ein registrierter Nutzer

  Szenario: Erfolgreiche Anmeldung
    Gegeben sei der Nutzer ist auf der Anmeldeseite
    Wenn der Nutzer gültige Zugangsdaten eingibt
    Und der Nutzer auf Anmelden klickt
    Dann sieht der Nutzer das Dashboard
```

- [ ] **Step 2: Core-Tests und App-Build ein letztes Mal laufen lassen**

Run:
```bash
(cd Core && swift test 2>&1 | tail -5)
xcodegen generate && xcodebuild -project guerkchen.xcodeproj -scheme guerkchen -configuration Debug -derivedDataPath build/DerivedData build 2>&1 | tail -3
```
Expected: alle Tests grün, `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Gesamtabnahme mit dem Beispielprojekt**

`open build/DerivedData/Build/Products/Debug/guerkchen.app`, dann `Examples/demo-project` öffnen und diese Liste abarbeiten:

1. Baum zeigt genau `anmeldung.feature`, `checkout.feature`, `login.feature`.
2. `login.feature` öffnen: Tag orange, `Feature`/`Background`/`Scenario`/`Scenario Outline`/`Examples` in ihren Kategoriefarben, Steps grün, Tabelle braun.
3. `checkout.feature` öffnen: Doc-String pink, inklusive der Begrenzer.
4. `anmeldung.feature` öffnen: Sprachzeile grau, deutsche Schlüsselwörter gefärbt.
5. In `checkout.feature` eine neue Zeile unter `And the cart is not empty` beginnen, `g` tippen → „Given“; Enter; `a u` → „a user exists“, „a user is logged in“, „a user is logged out“, „a user is on the login page“ (aus `login.feature`). Tab übernimmt.
6. In `anmeldung.feature` neue Zeile, `Wenn ` tippen → nur deutsche Steps, keine englischen.
7. Eine Sekunde nach der letzten Änderung: `git status` zeigt die Datei als geändert (Autosave).
8. Rechtsklick auf Projektordner → neue Datei `payment` → Datei erscheint, ist geöffnet, enthält `Feature: payment`.
9. Cmd+, → Farbe für Steps auf Rot → Editor färbt sofort um. Reset → zurück auf Grün.
10. App beenden, neu starten → `demo-project` ist wieder offen.
11. `git checkout Examples/` ausführen, um die Teständerungen an den Beispieldateien zu verwerfen (die Datei `payment.feature` löschen).

- [ ] **Step 4: Commit**

```bash
git add Examples
git commit -m "docs: add demo project with English and German feature files

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011S5k2e5dQPuDZsS3TEyEYB"
```

---

## Hinweise für die Ausführung

- Bei Compiler-Fehlern zur Actor-Isolation im Package (Swift 6): Die C-Callback-Closure in `FolderWatcher` darf keine Captures haben; `self` kommt ausschließlich über den `info`-Zeiger.
- Bei Fehlern der Form „main actor-isolated property … cannot be referenced from a nonisolated context“ im App-Target: Betroffene Klasse mit `@MainActor` annotieren, nicht die Isolation aufheben.
- `standardizedFileURL` löst `/var` nach `/private/var` auf. Alle URL-Vergleiche im Projekt laufen über standardisierte URLs; `FileNode.url` und die Rückgaben von `FileOperations` sind bereits standardisiert.
- XcodeGen muss nach jeder neuen Datei erneut laufen (`xcodegen generate`), da das `.xcodeproj` nicht eingecheckt ist.
