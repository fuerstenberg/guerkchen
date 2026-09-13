import Foundation

/// Kurzerklärung eines Gherkin-Schlüsselworts in Alltagssprache – für Leute, die keine
/// Software entwickeln: ein Satz, was das Wort bedeutet, und ein kurzes Beispiel dazu.
///
/// Die Beispiele werden mit den Wörtern des jeweiligen Dialekts gebaut, damit sie zu der
/// Datei passen, die gerade offen ist ("Given" in einer englischen, "Angenommen" in einer
/// deutschen Datei). Die Erklärungen selbst sind deutsch wie die übrige Oberfläche.
public struct KeywordHelp: Sendable, Equatable, Identifiable {
    public let category: KeywordCategory
    /// Das Schlüsselwort in der Sprache der Datei, z. B. "Given" oder "Angenommen".
    public let keyword: String
    /// Gleichbedeutende Schreibweisen im selben Dialekt, z. B. "Gegeben sei".
    public let alternatives: [String]
    /// Ein Satz in Alltagssprache.
    public let summary: String
    /// Wenige Zeilen Gherkin, in denen das Schlüsselwort vorkommt.
    public let example: String

    public var id: KeywordCategory { category }

    /// Alle Schlüsselwörter in Lesereihenfolge: erst der Rahmen, dann die Schritte.
    public static func all(for dialect: GherkinDialect) -> [KeywordHelp] {
        KeywordCategory.allCases.map { entry(for: $0, in: dialect) }
    }

    public static func entry(for category: KeywordCategory, in dialect: GherkinDialect) -> KeywordHelp {
        let names = usableKeywords(for: category, in: dialect)
        return KeywordHelp(category: category,
                           keyword: names.first ?? "",
                           alternatives: Array(names.dropFirst()),
                           summary: summary(for: category),
                           example: example(for: category, in: dialect))
    }

    /// Drei, vier Wörter für die Vorschlagsliste im Editor – dort ist kein Platz für mehr.
    public static func hint(for category: KeywordCategory) -> String {
        switch category {
        case .feature: return "Überschrift der Datei"
        case .rule: return "Regel für mehrere Beispiele"
        case .background: return "gilt für jedes Beispiel"
        case .scenario: return "ein einzelner Fall"
        case .scenarioOutline: return "Fall mit Platzhaltern"
        case .examples: return "Tabelle der Platzhalterwerte"
        case .given: return "Ausgangslage"
        case .when: return "Aktion"
        case .then: return "erwartetes Ergebnis"
        case .and: return "weitere Zeile davon"
        case .but: return "weitere Zeile, aber verneint"
        }
    }

    // MARK: - Private

    /// "*" steht für "irgendein Schrittwort" und erklärt niemandem etwas. Dialekte ohne
    /// eigenes Wort für eine Kategorie fallen aufs Englische zurück.
    private static func usableKeywords(for category: KeywordCategory, in dialect: GherkinDialect) -> [String] {
        let names = dialect.keywords(for: category).filter { $0 != "*" }
        guard names.isEmpty else { return names }
        return GherkinLanguages.english.keywords(for: category).filter { $0 != "*" }
    }

    private static func keyword(_ category: KeywordCategory, in dialect: GherkinDialect) -> String {
        usableKeywords(for: category, in: dialect).first ?? ""
    }

    private static func summary(for category: KeywordCategory) -> String {
        switch category {
        case .feature:
            return "Die Überschrift der Datei: Worum geht es hier? Darunter passen drei Zeilen für Rolle, Ziel und Nutzen."
        case .rule:
            return "Eine Regel, die für die Beispiele darunter gilt – praktisch, wenn eine Datei mehrere Regeln beschreibt."
        case .background:
            return "Was vor jedem Beispiel schon gilt, damit man es nicht in jedem einzelnen wiederholen muss."
        case .scenario:
            return "Ein einzelner Fall, Schritt für Schritt: Ausgangslage, Aktion, erwartetes Ergebnis."
        case .scenarioOutline:
            return "Derselbe Fall mehrmals mit wechselnden Werten. Die Platzhalter stehen in spitzen Klammern."
        case .examples:
            return "Die Tabelle mit den Werten für die Platzhalter – eine Zeile pro Durchlauf."
        case .given:
            return "Die Ausgangslage: Was gilt schon, bevor etwas passiert?"
        case .when:
            return "Die Aktion: Was tut jemand, oder was passiert?"
        case .then:
            return "Das erwartete Ergebnis: Was muss danach zu sehen sein?"
        case .and:
            return "Hängt eine weitere Zeile an die vorherige an, damit man das Wort davor nicht wiederholt."
        case .but:
            return "Wie „Und“, nur für den Gegensatz – liest sich besser bei „… aber nicht …“."
        }
    }

    private static func example(for category: KeywordCategory, in dialect: GherkinDialect) -> String {
        // Blockwörter stehen mit Doppelpunkt am Zeilenanfang, Schrittwörter mit Leerzeichen.
        func block(_ category: KeywordCategory) -> String { keyword(category, in: dialect) + ":" }
        func step(_ category: KeywordCategory) -> String { keyword(category, in: dialect) + " " }

        switch category {
        case .feature:
            return """
            \(block(.feature)) Anmeldung
              Als registrierter Kunde
              möchte ich mich anmelden können,
              damit ich meine Bestellungen sehe
            """
        case .rule:
            return """
            \(block(.rule)) Ab 50 € Bestellwert ist der Versand kostenlos

              \(block(.scenario)) Bestellung über 60 €
                \(step(.then))steht als Versandkosten 0,00 € da
            """
        case .background:
            return """
            \(block(.background))
              \(step(.given))der Kunde ist angemeldet
              \(step(.and))sein Warenkorb ist leer
            """
        case .scenario:
            return """
            \(block(.scenario)) Anmeldung mit richtigem Passwort
              \(step(.given))der Kunde ist auf der Anmeldeseite
              \(step(.when))er sein richtiges Passwort eingibt
              \(step(.then))sieht er seine Bestellübersicht
            """
        case .scenarioOutline:
            return """
            \(block(.scenarioOutline)) Anmeldung schlägt fehl
              \(step(.when))der Kunde <Passwort> eingibt
              \(step(.then))erscheint <Meldung>

              \(block(.examples))
                | Passwort | Meldung             |
                | leer     | Bitte ausfüllen     |
                | falsch   | Passwort ist falsch |
            """
        case .examples:
            return """
            \(block(.examples))
              | Passwort | Meldung             |
              | leer     | Bitte ausfüllen     |
              | falsch   | Passwort ist falsch |
            """
        case .given:
            return "\(step(.given))der Kunde hat drei Artikel im Warenkorb"
        case .when:
            return "\(step(.when))er auf „Jetzt bestellen“ klickt"
        case .then:
            return "\(step(.then))sieht er die Bestellbestätigung"
        case .and:
            return """
            \(step(.given))der Kunde ist angemeldet
            \(step(.and))sein Warenkorb ist leer
            """
        case .but:
            return """
            \(step(.then))sieht er seine eigenen Bestellungen
            \(step(.but))er sieht keine fremden Bestellungen
            """
        }
    }
}
