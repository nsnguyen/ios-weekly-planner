import CoreGraphics

/// Three discrete text-size steps that scale handwriting-font elements.
/// System-font elements (chrome, eyebrows) ignore this and stay at their
/// fixed pixel sizes. Applied through the `.handwritingScale(_:)` view
/// modifier in `View+InkColor.swift`.
enum PaperSize: String, CaseIterable, Hashable, Codable {
    case s
    case m
    case l

    /// Multiplier applied to handwriting-font sizes. Values from the mock.
    var scale: CGFloat {
        switch self {
        case .s: 0.90
        case .m: 1.00
        case .l: 1.14
        }
    }

    var displayName: String {
        switch self {
        case .s: "Small"
        case .m: "Medium"
        case .l: "Large"
        }
    }
}
