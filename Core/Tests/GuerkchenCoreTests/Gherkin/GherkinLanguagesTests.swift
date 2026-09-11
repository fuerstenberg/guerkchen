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
