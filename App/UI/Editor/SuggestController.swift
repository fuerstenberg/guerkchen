import AppKit
import GuerkchenCore

/// Verbindet NSTextView, SuggestEngine und SuggestPanel.
@MainActor
final class SuggestController {
    var stepsProvider: (String) -> [String] = { _ in [] }
    /// Die Vorschläge landen so im Editor, wie sie hier stehen – deshalb dieselbe Schrift.
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    private weak var textView: NSTextView?
    private let panel = SuggestPanel()
    private var suppressNextChange = false
    /// Zeile und Zeilenanfang (UTF-16-Offset im Gesamttext), für die das Panel gerade gilt.
    private var currentLine: String = ""
    private var currentLineLocation = 0
    private var deactivateObserver: NSObjectProtocol?

    init(textView: NSTextView) {
        self.textView = textView
        panel.onPick = { [weak self] _ in self?.accept() }
        // `hidesOnDeactivate` allein versteckt ein per `addChildWindow` gehängtes Panel
        // nicht zuverlässig, wenn die App inaktiv wird – deshalb zusätzlich explizit beobachten.
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    /// Sicherheitsnetz: Wird der Editor abgebaut, während das Panel offen ist, bliebe es
    /// sonst als Child-Window des Hauptfensters sichtbar zurück.
    isolated deinit {
        panel.hide()
        if let deactivateObserver {
            NotificationCenter.default.removeObserver(deactivateObserver)
        }
    }

    func textDidChange() {
        if suppressNextChange {
            suppressNextChange = false
            hide()
            return
        }
        refresh()
    }

    func selectionDidChange() {
        guard panel.isVisible, let textView else { return }
        // `accept()` löst über `insertText` selbst eine Selektionsänderung aus – die darf
        // das Panel nicht neu aufbauen.
        guard !suppressNextChange else { return }
        let selection = textView.selectedRange()
        let lineRange = (textView.string as NSString).lineRange(for: NSRange(location: selection.location, length: 0))
        if selection.length > 0 || lineRange.location != currentLineLocation {
            hide()
        } else {
            // Vorschläge und `replacementRange` gelten für eine bestimmte Cursorposition:
            // neu berechnen statt stehen lassen. `refresh()` versteckt sich selbst, wenn nichts passt.
            refresh()
        }
    }

    func hide() {
        panel.hide()
    }

    /// Fängt Tasten ab, solange das Panel sichtbar ist. `complete(_:)` wird immer geschluckt,
    /// damit NSTextView nicht seine eigene Wortvervollständigung öffnet. Escape (`cancelOperation:`)
    /// wird nur geschluckt, solange das Panel sichtbar ist, damit z. B. die Find-Bar mit Escape
    /// weiterhin normal geschlossen werden kann.
    func handle(_ selector: Selector) -> Bool {
        if selector == #selector(NSResponder.complete(_:)) { return true }
        guard panel.isVisible else { return false }
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            panel.selectPrevious()
            return true
        case #selector(NSResponder.moveDown(_:)):
            panel.selectNext()
            return true
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
            accept()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
            return true
        default:
            return false
        }
    }

    // MARK: - Private

    private func refresh() {
        guard let textView, let window = textView.window else { hide(); return }
        let text = textView.string
        let selection = textView.selectedRange()
        guard selection.length == 0 else { hide(); return }

        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selection.location, length: 0))
        var line = nsText.substring(with: lineRange)
        while line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }

        let cursorOffset = selection.location - lineRange.location
        guard cursorOffset >= 0, cursorOffset <= line.utf16.count else { hide(); return }
        let cursor = String.Index(utf16Offset: cursorOffset, in: line)

        let dialect = LineScanner.dialect(for: text)
        let suggestions = SuggestEngine.suggestions(
            line: line, cursor: cursor, dialect: dialect,
            steps: stepsProvider(dialect.code),
            isFirstLine: lineRange.location == 0,
            inDocString: Self.isInsideDocString(text: text, lineLocation: lineRange.location, dialect: dialect))

        guard !suggestions.isEmpty else { hide(); return }
        currentLine = line
        currentLineLocation = lineRange.location

        let cursorRect = textView.firstRect(forCharacterRange: NSRange(location: selection.location, length: 0), actualRange: nil)
        panel.show(suggestions, font: font, below: cursorRect, in: window)
    }

    /// Ungerade Anzahl Doc-String-Begrenzer vor dieser Zeile → wir sind in einem Doc-String.
    private static func isInsideDocString(text: String, lineLocation: Int, dialect: GherkinDialect) -> Bool {
        var delimiters = 0
        for scanned in LineScanner.scan(text, dialect: dialect) {
            guard scanned.range.lowerBound.utf16Offset(in: text) < lineLocation else { break }
            if scanned.kind == .docStringDelimiter { delimiters += 1 }
        }
        return delimiters % 2 == 1
    }

    private func accept() {
        guard let textView, let suggestion = panel.selectedSuggestion else { hide(); return }
        let start = currentLineLocation + suggestion.replacementRange.lowerBound.utf16Offset(in: currentLine)
        let end = currentLineLocation + suggestion.replacementRange.upperBound.utf16Offset(in: currentLine)
        let range = NSRange(location: start, length: end - start)

        suppressNextChange = true
        if textView.shouldChangeText(in: range, replacementString: suggestion.insertion) {
            textView.insertText(suggestion.insertion, replacementRange: range)
        }
        suppressNextChange = false
        hide()
    }
}
