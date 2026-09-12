import Foundation
import GuerkchenCore

enum HighlightCategory: String, CaseIterable, Identifiable {
    case featureRule, background, scenario, step, comment, tag, table, docString

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featureRule: return "Feature / Rule"
        case .background: return "Background"
        case .scenario: return "Scenario / Outline / Examples"
        case .step: return "Given / When / Then / And / But"
        case .comment: return "Kommentare"
        case .tag: return "Tags"
        case .table: return "Tabellen"
        case .docString: return "Doc-Strings"
        }
    }

    var defaultHex: String {
        switch self {
        case .featureRule: return "#AF52DE"
        case .background: return "#00A99D"
        case .scenario: return "#007AFF"
        case .step: return "#34C759"
        case .comment: return "#8E8E93"
        case .tag: return "#FF9500"
        case .table: return "#A2845E"
        case .docString: return "#FF2D55"
        }
    }

    init?(keyword: KeywordCategory) {
        switch keyword {
        case .feature, .rule: self = .featureRule
        case .background: self = .background
        case .scenario, .scenarioOutline, .examples: self = .scenario
        case .given, .when, .then, .and, .but: self = .step
        }
    }

    static func forLine(_ kind: LineKind) -> HighlightCategory? {
        switch kind {
        case .comment, .languageLine: return .comment
        case .tag: return .tag
        case .tableRow: return .table
        case .docStringDelimiter, .docStringContent: return .docString
        case .keyword(let category, _, _): return HighlightCategory(keyword: category)
        case .blank, .other: return nil
        }
    }
}
