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
    private nonisolated(unsafe) static let languageRegex = /^\s*#\s*language\s*:\s*([A-Za-z][A-Za-z0-9_-]*)\s*$/

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
