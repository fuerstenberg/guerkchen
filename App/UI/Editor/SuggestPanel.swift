import AppKit
import SwiftUI
import GuerkchenCore

struct SuggestListView: View {
    /// Die Zeilen wachsen mit der eingestellten Editorschrift mit.
    static func rowHeight(for font: NSFont) -> CGFloat {
        max(24, ceil(font.ascender - font.descender + font.leading) + 8)
    }

    let suggestions: [Suggestion]
    let selectedIndex: Int
    let font: NSFont
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: 8) {
                    Image(systemName: icon(for: suggestion.kind))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(suggestion.label)
                        .font(Font(font))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    // Drei Worte, was das Schlüsselwort bedeutet – ausführlich steht es
                    // im Fenster „Schlüsselwörter erklärt“.
                    if let hint = hint(for: suggestion) {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: Self.rowHeight(for: font))
                .background(index == selectedIndex ? Color.accentColor.opacity(0.25) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
                .onTapGesture { onPick(index) }
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
    }

    private func hint(for suggestion: Suggestion) -> String? {
        guard case let .keyword(category) = suggestion.kind else { return nil }
        return KeywordHelp.hint(for: category)
    }

    private func icon(for kind: SuggestionKind) -> String {
        switch kind {
        case .keyword: return "textformat"
        case .step: return "text.line.first.and.arrowtriangle.forward"
        }
    }
}

@MainActor
final class SuggestPanel: NSPanel {
    static let width: CGFloat = 380

    var onPick: ((Int) -> Void)?
    private(set) var suggestions: [Suggestion] = []
    private(set) var selectedIndex = 0
    private var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    private let hosting: NSHostingView<SuggestListView>

    var selectedSuggestion: Suggestion? {
        suggestions.indices.contains(selectedIndex) ? suggestions[selectedIndex] : nil
    }

    init() {
        hosting = NSHostingView(rootView: SuggestListView(suggestions: [], selectedIndex: 0,
                                                          font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                                                          onPick: { _ in }))
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = true
        isReleasedWhenClosed = false
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ suggestions: [Suggestion], font: NSFont, below cursorRect: NSRect, in window: NSWindow) {
        self.suggestions = suggestions
        self.font = font
        selectedIndex = 0
        render()

        let height = CGFloat(suggestions.count) * SuggestListView.rowHeight(for: font) + 8
        var origin = NSPoint(x: cursorRect.minX, y: cursorRect.minY - height - 2)
        if let screen = window.screen {
            let visible = screen.visibleFrame
            if origin.y < visible.minY { origin.y = cursorRect.maxY + 2 }
            if origin.x + Self.width > visible.maxX { origin.x = visible.maxX - Self.width }
        }
        setFrame(NSRect(origin: origin, size: NSSize(width: Self.width, height: height)), display: true)
        if parent == nil { window.addChildWindow(self, ordered: .above) }
        orderFront(nil)
    }

    func hide() {
        // Immer abhängen: `hidesOnDeactivate` kann das Panel schon unsichtbar gemacht haben,
        // ein noch gehängtes Child-Window käme mit dem Parent wieder nach vorn.
        parent?.removeChildWindow(self)
        if isVisible { orderOut(nil) }
    }

    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        render()
    }

    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        render()
    }

    private func render() {
        hosting.rootView = SuggestListView(suggestions: suggestions, selectedIndex: selectedIndex, font: font) { [weak self] index in
            self?.selectedIndex = index
            self?.onPick?(index)
        }
    }
}
