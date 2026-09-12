import AppKit
import SwiftUI
import GuerkchenCore

struct SuggestListView: View {
    static let rowHeight: CGFloat = 24

    let suggestions: [Suggestion]
    let selectedIndex: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: 8) {
                    Image(systemName: icon(for: suggestion.kind))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(suggestion.label)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: Self.rowHeight)
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
    private let hosting: NSHostingView<SuggestListView>

    var selectedSuggestion: Suggestion? {
        suggestions.indices.contains(selectedIndex) ? suggestions[selectedIndex] : nil
    }

    init() {
        hosting = NSHostingView(rootView: SuggestListView(suggestions: [], selectedIndex: 0, onPick: { _ in }))
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

    func show(_ suggestions: [Suggestion], below cursorRect: NSRect, in window: NSWindow) {
        self.suggestions = suggestions
        selectedIndex = 0
        render()

        let height = CGFloat(suggestions.count) * SuggestListView.rowHeight + 8
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
        hosting.rootView = SuggestListView(suggestions: suggestions, selectedIndex: selectedIndex) { [weak self] index in
            self?.selectedIndex = index
            self?.onPick?(index)
        }
    }
}
