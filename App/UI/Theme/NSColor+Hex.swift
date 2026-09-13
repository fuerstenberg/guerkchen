import AppKit

extension NSColor {
    /// "#RRGGBB" oder "RRGGBB"
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, value.allSatisfy(\.isHexDigit), let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) ?? usingColorSpace(.deviceRGB) else { return "#000000" }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Helligkeit nach Rec. 601 – entscheidet, ob heller oder dunkler Text darauf lesbar ist.
    var isDark: Bool {
        guard let c = usingColorSpace(.sRGB) ?? usingColorSpace(.deviceRGB) else { return false }
        let brightness = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return brightness < 0.55
    }
}
