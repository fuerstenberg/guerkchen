import AppKit
import SwiftUI
import GuerkchenCore

struct GherkinTextView: NSViewRepresentable {
    let document: EditorDocument
    /// Nur damit der View-Wert sich ändert, wenn sich der Text des Dokuments ändert
    /// (z. B. nach einer externen Änderung). Der Coordinator arbeitet weiter mit `document`.
    let text: String
    let theme: EditorTheme
    let stepsProvider: (String) -> [String]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        context.coordinator.textView = textView
        context.coordinator.suggest = SuggestController(textView: textView)
        context.coordinator.update(document: document, theme: theme, stepsProvider: stepsProvider)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(document: document, theme: theme, stepsProvider: stepsProvider)
    }

    /// Deterministischer Abbau: ohne das bliebe ein offenes Vorschlagspanel am Hauptfenster hängen.
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.suggest?.hide()
        coordinator.suggest = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var suggest: SuggestController?
        private var document: EditorDocument?
        private var theme: EditorTheme?
        private var isApplying = false

        func update(document: EditorDocument, theme: EditorTheme, stepsProvider: @escaping (String) -> [String]) {
            suggest?.stepsProvider = stepsProvider
            guard let textView else { return }
            let documentChanged = document !== self.document
            let themeChanged = theme != self.theme
            self.document = document
            self.theme = theme

            if themeChanged { applyTheme(theme) }

            if documentChanged || textView.string != document.text {
                isApplying = true
                textView.string = document.text
                // Der Puffer wurde komplett ersetzt, ohne Undo-Aktion zu registrieren – alte
                // Undo-Schritte zeigen auf Bereiche, die es nicht mehr gibt.
                textView.undoManager?.removeAllActions()
                if documentChanged {
                    textView.setSelectedRange(NSRange(location: 0, length: 0))
                }
                isApplying = false
                suggest?.hide()
                rehighlight()
            } else if themeChanged {
                rehighlight()
            }
        }

        func rehighlight() {
            guard let textView, let theme, let storage = textView.textStorage else { return }
            SyntaxHighlighter.highlight(storage: storage, theme: theme)
            textView.typingAttributes = [.font: theme.font, .foregroundColor: theme.textColor]
        }

        // MARK: - Private

        private func applyTheme(_ theme: EditorTheme) {
            guard let textView else { return }
            let background = theme.backgroundColor
            textView.font = theme.font
            textView.drawsBackground = true
            textView.backgroundColor = background
            textView.insertionPointColor = theme.textColor
            suggest?.font = theme.font

            guard let scrollView = textView.enclosingScrollView else { return }
            scrollView.drawsBackground = true
            scrollView.backgroundColor = background
            // Bei eigenem Hintergrund passen Scroller und Auswahlfarbe sonst nicht dazu.
            if theme.customBackgroundColor != nil {
                scrollView.appearance = NSAppearance(named: background.isDark ? .darkAqua : .aqua)
            } else {
                scrollView.appearance = nil
            }
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView, let document else { return }
            document.updateText(textView.string)
            rehighlight()
            suggest?.textDidChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplying else { return }
            suggest?.selectionDidChange()
        }

        func textDidEndEditing(_ notification: Notification) {
            suggest?.hide()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            suggest?.handle(commandSelector) ?? false
        }
    }
}
