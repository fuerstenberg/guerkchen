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
