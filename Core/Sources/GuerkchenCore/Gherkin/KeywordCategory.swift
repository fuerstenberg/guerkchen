public enum KeywordCategory: String, CaseIterable, Sendable, Codable {
    case feature, rule, background, scenario, scenarioOutline, examples
    case given, when, then, and, but

    public var isStep: Bool {
        switch self {
        case .given, .when, .then, .and, .but: return true
        default: return false
        }
    }
}
