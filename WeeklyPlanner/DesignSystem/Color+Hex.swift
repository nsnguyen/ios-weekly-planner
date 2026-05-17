import SwiftUI

extension Color {
    /// Initializes a color from a hex string in sRGB. Accepts:
    ///   - `"#RRGGBB"` — fully opaque
    ///   - `"#RRGGBBAA"` — explicit alpha (`00` transparent, `FF` opaque)
    ///   - `"#"` prefix optional. Case-insensitive.
    /// Invalid strings collapse to fully transparent black so a typo is visible at runtime.
    init(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let r: Double
        let g: Double
        let b: Double
        let a: Double

        switch trimmed.count {
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        case 6: // RRGGBB
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        default:
            r = 0
            g = 0
            b = 0
            a = 0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// CSS-style `rgba()` factory: 0–255 channels with a 0...1 alpha. Used for
    /// translucent rule / red-line / shadow colors in `PaperTheme`.
    static func rgba(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Double) -> Color {
        Color(.sRGB,
              red: Double(red) / 255.0,
              green: Double(green) / 255.0,
              blue: Double(blue) / 255.0,
              opacity: alpha)
    }
}
