import AppKit
import GuerkchenCore

enum SyntaxHighlighter {
    @MainActor
    static func highlight(storage: NSTextStorage, theme: EditorTheme) {
        let text = storage.string
        let dialect = LineScanner.dialect(for: text)
        let full = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        storage.addAttributes([.font: theme.font, .foregroundColor: theme.textColor], range: full)
        for line in LineScanner.scan(text, dialect: dialect) {
            guard let category = HighlightCategory.forLine(line.kind) else { continue }
            let color = theme.color(for: category)
            let range: Range<String.Index>
            if case let .keyword(_, keywordRange, _) = line.kind {
                range = keywordRange
            } else {
                range = line.range
            }
            storage.addAttribute(.foregroundColor, value: color, range: NSRange(range, in: text))
        }
        storage.endEditing()
    }
}
