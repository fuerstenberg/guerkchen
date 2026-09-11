# guerkchen – Gherkin-Editor für macOS (Design-Spezifikation)

Stand: 2026-09-12. Freigegeben im Brainstorming mit dem Nutzer.

## Context

guerkchen ist ein macOS-Editor für Gherkin-Dateien (`.feature`). Zweck: Anforderungen an eine KI immer im selben festen Format beschreiben (Feature mit Rolle und Ziel, Given/When/Then). Ein Ordner ist ein Projekt. Das Besondere ist der Suggest-Mechanismus: Beim Tippen werden Schlüsselwörter des gewählten Gherkin-Dialekts und bereits im Projekt existierende Step-Texte vorgeschlagen, damit im ganzen Projekt ein einheitliches Vokabular entsteht.

Repo ist leer. Xcode 26.6, Swift 6.3, XcodeGen installiert. Ziel: macOS 15.

## Entscheidungen (mit dem Nutzer geklärt)

- Sprachzeile nur offiziell: `# language: de` (Whitespace-tolerant). Fehlt sie, gilt `en`.
- Suggest erscheint automatisch beim Tippen (ab 1 Zeichen). Escape schließt, Enter/Tab übernimmt, Pfeiltasten wählen.
- Matching: Fuzzy (Subsequenz, case-insensitive, Bonus für zusammenhängende Treffer und Wortanfänge). Max. 10 Einträge.
- Step-Pool: alle Steps unabhängig vom Schlüsselwort, aber nur aus Dateien gleicher Sprache. Der exakt schon getippte Text wird ausgeschlossen.
- Dateibaum: nur Ordner und `.feature`; Anlegen, Umbenennen, Löschen (Papierkorb) per Kontextmenü.
- Eine Datei gleichzeitig offen; Auswahl im Baum wechselt. Autosave ~1 s nach letzter Änderung, beim Dateiwechsel und beim Beenden.
- Farben pro Kategorie (8): Feature/Rule, Background, Scenario/Scenario Outline/Examples, Steps (Given/When/Then/And/But), Kommentare, Tags, Tabellen, Doc-Strings. Einstellbar im Settings-Fenster, mit Reset.
- Kein separates Schlüsselwort-Menü, nur Suggest.
- Letztes Projekt beim Start wieder öffnen, plus "Zuletzt geöffnet" (10 Einträge), als Security-Scoped Bookmarks.
- Ansatz A: SwiftUI-Shell + AppKit `NSTextView` via `NSViewRepresentable`. Keine Fremdabhängigkeiten.

## Architektur (4 Schichten, je eigener Ordner unter `Sources/guerkchen/`)

1. **Gherkin** (reines Swift): 
   - `GherkinLanguages` lädt die eingebettete offizielle `gherkin-languages.json` (cucumber/gherkin, MIT) und liefert pro Code einen `GherkinDialect` (Schlüsselwörter je Kategorie: feature, rule, background, scenario, scenarioOutline, examples, given, when, then, and, but).
   - `LineScanner` klassifiziert jede Zeile: languageLine, comment, tag, keywordLine(category, keywordRange, textRange), tableRow, docStringDelimiter/docStringContent, blank, other. Hält Doc-String-Zustand über Zeilen. Kein vollständiger Parser.
2. **Project** (Modell): 
   - `ProjectFolder` öffnet Ordner, baut gefilterten Baum, beobachtet per `DispatchSource`/FSEvents, bietet create/rename/trash.
   - `StepIndex`: je Sprache Set aller eindeutigen Step-Texte (ohne Schlüsselwort, getrimmt) aus allen `.feature`-Dateien; Rebuild bei Änderungen und nach Autosave.
3. **Suggest** (reines Swift): 
   - `SuggestEngine.suggestions(line:cursor:dialect:index:)` liefert einen von drei Modi:
     - **keyword**: Die Zeile (ohne Einrückung) beginnt mit einem Buchstaben und enthält bis zum Cursor noch kein vollständiges Schlüsselwort des Dialekts (Blockschlüsselwort gefolgt von `:`, Step-Schlüsselwort gefolgt von Leerzeichen). Der getippte Text bis zum Cursor ist die Anfrage, auch mit Leerzeichen, damit `Scenario O` weiter `Scenario Outline` findet.
     - **step**: Die Zeile beginnt mit einem Step-Schlüsselwort des Dialekts und der Cursor steht dahinter. Anfrage ist der Text zwischen Schlüsselwort und Cursor, getrimmt. Bei leerer Anfrage werden alle Steps der Sprache gezeigt.
     - **none**: Kommentar, Tag, Tabelle, Doc-String, Sprachzeile, oder Blockschlüsselwortzeile hinter dem `:`.
   - `FuzzyMatcher.score(query:candidate:)`.
   - Übernahme: Schlüsselwort ersetzt getipptes Wort; Feature/Rule/Background/Scenario/Scenario Outline/Examples bekommen `: ` angehängt, Steps ein Leerzeichen. Step-Text ersetzt alles nach dem Schlüsselwort.
4. **UI** (SwiftUI + AppKit): 
   - `MainWindow` mit `NavigationSplitView`: Seitenleiste `FileTreeView`, Detail `EditorView`.
   - `GherkinTextView` (`NSViewRepresentable` um `NSTextView`), Highlighting über `NSTextStorageDelegate` nach jeder Änderung: Schlüsselwort gefärbt, Rest Textfarbe; Kommentar/Tag/Tabelle/Doc-String ganze Zeile.
   - `SuggestPopover`: rahmenloses Kind-`NSPanel` mit `NSTableView` unter der Cursorzeile; fängt Pfeile, Enter, Tab, Escape ab.
   - `SettingsView`: 8 `ColorPicker`, Reset. Farben als Hex in `UserDefaults`, Änderung färbt sofort neu.
   - Sandbox mit `com.apple.security.files.user-selected.read-write`.

## Fehlerfälle

- Externe Änderung: Index neu bauen; offene Datei ohne ungesicherte Änderungen neu laden, sonst gewinnt Editor.
- Datei/Ordner verschwindet: Auswahl aufheben, Editor leeren, Baum aktualisieren.
- Kein UTF-8: im Baum sichtbar, Hinweis statt Inhalt, nicht im Index.
- Unbekannter Sprachcode: als Kommentar gefärbt, Fallback `en`.
- Speichern fehlgeschlagen: Hinweis, Text bleibt, nächster Autosave versucht erneut.
- Rename auf bestehenden Namen: ablehnen; Endung `.feature` beim Anlegen ergänzen.

## Projektstruktur

Die drei UI-freien Schichten liegen in einem lokalen Swift-Package `Core`, damit ihre Tests mit `swift test` ohne Xcode-Testhost laufen. Die App ist ein XcodeGen-Target, das dieses Package einbindet.

```
project.yml                              # XcodeGen: Target guerkchen (macOS 15), bindet Core ein
Core/Package.swift                       # Library GuerkchenCore, Swift 6, macOS 15
Core/Sources/GuerkchenCore/{Gherkin,Project,Suggest}/
Core/Sources/GuerkchenCore/Resources/gherkin-languages.json
Core/Tests/GuerkchenCoreTests/{Gherkin,Project,Suggest}/
App/{App,UI}/                            # SwiftUI + AppKit, Swift 5 Sprachmodus
Config/Info.plist, Config/guerkchen.entitlements   # von XcodeGen erzeugt
Examples/demo-project/*.feature          # 3 Dateien, en + de
docs/superpowers/specs/2026-09-12-guerkchen-design.md
```

## Tests / Verifikation

- Swift Testing für Gherkin, Suggest, Project. Die 4 Beispiele aus der Anfrage werden Testfälle (g→Given, b→Background, "Given " + "a u"→"a user…", sc→Scenario, Scenario Outline).
- Tests: `cd Core && swift test`. Build der App: `xcodegen generate && xcodebuild -scheme guerkchen -configuration Debug build`.
- Manuell: App starten, `Examples/demo-project` öffnen, Tippen/Suggest/Farben/Umbenennen prüfen.

