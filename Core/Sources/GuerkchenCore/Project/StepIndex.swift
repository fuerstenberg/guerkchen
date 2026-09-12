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
