import Foundation

/// Selectable page background (Phase 44 #59 #78). Raw value is persisted
/// in `UserSettings.templateKey`.
enum PaperTemplate: String, CaseIterable, Hashable, Sendable {
    case ruled
    case blank
    case dotGrid
    case grid

    var displayName: String {
        switch self {
        case .ruled: "Ruled"
        case .blank: "Blank"
        case .dotGrid: "Dot grid"
        case .grid: "Grid"
        }
    }

    /// The red margin line belongs to the ruled-notebook look only.
    var showsRedMargin: Bool {
        self == .ruled
    }
}
