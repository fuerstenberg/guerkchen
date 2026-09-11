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
