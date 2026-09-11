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
