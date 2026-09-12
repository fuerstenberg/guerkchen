import AppKit

@MainActor
final class SuggestController {
    var stepsProvider: (String) -> [String] = { _ in [] }
    init(textView: NSTextView) {}
    func textDidChange() {}
    func selectionDidChange() {}
    func hide() {}
    func handle(_ selector: Selector) -> Bool { false }
}
