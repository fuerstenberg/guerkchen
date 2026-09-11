public enum FuzzyMatcher {
    private static let prefixBonus = 5
    private static let consecutiveBonus = 3
    private static let wordStartBonus = 2
    private static let gapPenalty = 1

    /// Greedy Subsequenz-Suche, case-insensitive. nil wenn nicht alle Query-Zeichen
    /// in Reihenfolge im Kandidaten vorkommen.
    public static func score(query: String, candidate: String) -> Int? {
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        if q.isEmpty { return 0 }

        var score = 0
        var qi = 0
        var previousMatch: Int? = nil

        for (ci, ch) in c.enumerated() where qi < q.count {
            guard ch == q[qi] else { continue }
            score += 1
            if ci == 0 { score += prefixBonus }
            if let prev = previousMatch {
                if ci == prev + 1 {
                    score += consecutiveBonus
                } else {
                    score -= gapPenalty * (ci - prev - 1)
                }
            } else if ci > 0 {
                score -= gapPenalty * ci
            }
            if ci > 0, !c[ci - 1].isLetter, !c[ci - 1].isNumber { score += wordStartBonus }
            previousMatch = ci
            qi += 1
        }
        return qi == q.count ? score : nil
    }

    /// Leere Query: rein alphabetisch. Sonst Score absteigend, dann kürzer zuerst, dann alphabetisch.
    public static func rank(query: String, candidates: [String], limit: Int) -> [String] {
        if query.isEmpty {
            return Array(candidates
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .prefix(limit))
        }
        return candidates
            .compactMap { candidate -> (String, Int)? in
                score(query: query, candidate: candidate).map { (candidate, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.count != rhs.0.count { return lhs.0.count < rhs.0.count }
                return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }
}
