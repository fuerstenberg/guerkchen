import Foundation

public struct StepIndex: Sendable, Equatable {
    private var table: [String: Set<String>] = [:]
    /// Sortierte Sicht auf `table`, bei jeder Mutation neu berechnet – `steps(for:)` läuft
    /// pro Tastendruck und darf nicht mit `localizedCaseInsensitiveCompare` sortieren.
    private var sortedTable: [String: [String]] = [:]

    public init() {}

    public var languages: [String] { table.keys.sorted() }

    public func steps(for languageCode: String) -> [String] {
        sortedTable[languageCode.lowercased()] ?? []
    }

    public mutating func add(text: String) {
        let dialect = LineScanner.dialect(for: text)
        var changed = false
        for line in LineScanner.scan(text, dialect: dialect) {
            guard case let .keyword(category, _, textRange) = line.kind, category.isStep else { continue }
            let step = text[textRange].trimmingCharacters(in: .whitespaces)
            guard !step.isEmpty else { continue }
            table[dialect.code, default: []].insert(step)
            changed = true
        }
        if changed { resort(dialect.code) }
    }

    /// Vergleicht nur die Rohdaten; `sortedTable` ist daraus abgeleitet.
    public static func == (lhs: StepIndex, rhs: StepIndex) -> Bool {
        lhs.table == rhs.table
    }

    private mutating func resort(_ languageCode: String) {
        sortedTable[languageCode] = (table[languageCode] ?? [])
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
