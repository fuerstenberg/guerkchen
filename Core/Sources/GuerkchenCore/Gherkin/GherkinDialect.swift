public struct GherkinDialect: Sendable, Equatable {
    public let code: String
    public let name: String
    public let native: String
    private let table: [KeywordCategory: [String]]

    /// Feature, Rule, Background, Scenario, Scenario Outline, Examples – längste zuerst.
    public let blockKeywords: [(keyword: String, category: KeywordCategory)]

    /// Given, When, Then, And, But (inkl. "*") – längste zuerst.
    public let stepKeywords: [(keyword: String, category: KeywordCategory)]

    /// Kandidaten für das Schlüsselwort-Dropdown: ohne "*", ohne Duplikate.
    public let suggestableKeywords: [(keyword: String, category: KeywordCategory)]

    public init(code: String, name: String, native: String, keywords: [KeywordCategory: [String]]) {
        self.code = code
        self.name = name
        self.native = native
        self.table = keywords
        // Einmal im Init berechnet: die Listen werden pro Zeile und pro Tastendruck gelesen.
        self.blockKeywords = Self.entries(in: keywords, for: KeywordCategory.allCases.filter { !$0.isStep })
        self.stepKeywords = Self.entries(in: keywords, for: KeywordCategory.allCases.filter(\.isStep))
        self.suggestableKeywords = Self.suggestable(in: keywords)
    }

    public func keywords(for category: KeywordCategory) -> [String] {
        table[category] ?? []
    }

    /// Handgeschrieben, weil Arrays von Tupeln nicht `Equatable` sind. Die abgeleiteten
    /// Schlüsselwortlisten hängen allein an `table` und müssen nicht verglichen werden.
    public static func == (lhs: GherkinDialect, rhs: GherkinDialect) -> Bool {
        lhs.code == rhs.code && lhs.name == rhs.name && lhs.native == rhs.native && lhs.table == rhs.table
    }

    private static func entries(in table: [KeywordCategory: [String]],
                                for categories: [KeywordCategory]) -> [(keyword: String, category: KeywordCategory)] {
        categories
            .flatMap { category in (table[category] ?? []).map { (keyword: $0, category: category) } }
            .sorted { $0.keyword.count > $1.keyword.count }
    }

    private static func suggestable(in table: [KeywordCategory: [String]]) -> [(keyword: String, category: KeywordCategory)] {
        var seen = Set<String>()
        var result: [(keyword: String, category: KeywordCategory)] = []
        for category in KeywordCategory.allCases {
            for keyword in (table[category] ?? []) where keyword != "*" && !seen.contains(keyword) {
                seen.insert(keyword)
                result.append((keyword, category))
            }
        }
        return result
    }
}
