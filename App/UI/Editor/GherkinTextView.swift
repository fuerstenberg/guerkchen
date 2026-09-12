import AppKit
import SwiftUI
import GuerkchenCore

struct GherkinTextView: NSViewRepresentable {
    let document: EditorDocument
    let palette: HighlightPalette
    let stepsProvider: (String) -> [String]

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = Self.font
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
        context.coordinator.update(document: document, palette: palette, stepsProvider: stepsProvider)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(document: document, palette: palette, stepsProvider: stepsProvider)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var suggest: SuggestController?
        private var document: EditorDocument?
        private var palette: HighlightPalette = [:]
        private var isApplying = false

        func update(document: EditorDocument, palette: HighlightPalette, stepsProvider: @escaping (String) -> [String]) {
            suggest?.stepsProvider = stepsProvider
            guard let textView else { return }
            let documentChanged = document !== self.document
            let paletteChanged = palette != self.palette
            self.document = document
            self.palette = palette

            if documentChanged || textView.string != document.text {
                isApplying = true
                textView.string = document.text
                if documentChanged {
                    textView.setSelectedRange(NSRange(location: 0, length: 0))
                    textView.undoManager?.removeAllActions()
                }
                isApplying = false
                suggest?.hide()
                rehighlight()
            } else if paletteChanged {
                rehighlight()
            }
        }

        func rehighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            SyntaxHighlighter.highlight(storage: storage, palette: palette, font: GherkinTextView.font)
            textView.typingAttributes = [.font: GherkinTextView.font, .foregroundColor: NSColor.textColor]
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
