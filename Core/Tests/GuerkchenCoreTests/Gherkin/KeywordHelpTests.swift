import Testing
@testable import GuerkchenCore

@Suite struct KeywordHelpTests {
    @Test func everyKeywordIsExplained() {
        let entries = KeywordHelp.all(for: GherkinLanguages.english)
        #expect(entries.count == KeywordCategory.allCases.count)
        for entry in entries {
            #expect(!entry.keyword.isEmpty)
            #expect(!entry.summary.isEmpty)
            #expect(!entry.example.isEmpty)
            #expect(!KeywordHelp.hint(for: entry.category).isEmpty)
        }
    }

    @Test func examplesUseTheKeywordsOfTheDialect() throws {
        let de = try #require(GherkinLanguages.dialect(for: "de"))
        let given = KeywordHelp.entry(for: .given, in: de)
        #expect(given.keyword == "Angenommen")
        #expect(given.example.hasPrefix("Angenommen "))

        let en = KeywordHelp.entry(for: .given, in: GherkinLanguages.english)
        #expect(en.keyword == "Given")
        #expect(en.example.hasPrefix("Given "))
    }

    @Test func exampleOfABlockKeywordStartsWithColon() throws {
        let de = try #require(GherkinLanguages.dialect(for: "de"))
        #expect(KeywordHelp.entry(for: .feature, in: de).example.hasPrefix("Funktionalität: "))
        #expect(KeywordHelp.entry(for: .examples, in: de).example.hasPrefix("Beispiele:"))
    }

    @Test func alternativeSpellingsAreListedWithoutTheStar() throws {
        let de = try #require(GherkinLanguages.dialect(for: "de"))
        let given = KeywordHelp.entry(for: .given, in: de)
        #expect(given.alternatives == ["Gegeben sei", "Gegeben seien"])
        #expect(!given.alternatives.contains("*"))
        #expect(!given.alternatives.contains(given.keyword))
    }

    @Test func dialectWithoutOwnWordFallsBackToEnglish() {
        let empty = GherkinDialect(code: "xx", name: "Empty", native: "Empty", keywords: [:])
        let entry = KeywordHelp.entry(for: .when, in: empty)
        #expect(entry.keyword == "When")
        #expect(entry.example.hasPrefix("When "))
    }
}
