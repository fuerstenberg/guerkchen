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
