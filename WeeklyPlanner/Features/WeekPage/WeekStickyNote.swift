import SwiftUI

/// Bottom-right paper sticky note on the week page. Yellow rectangle, slight
/// rotation, masking-tape strip at the top, eyebrow line, then one line of
/// AI-flavored summary text that varies by `weekOffset` (plus a special
/// "INBOX" variant when the current week has pending Gmail suggestions).
///
/// If `bodyText(for:inboxCount:)` returns `nil` for the given offset, the
/// whole view collapses to `EmptyView()` — the corner is left blank rather
/// than showing a placeholder. Caller is responsible for omitting it from
/// layout in that case (the EmptyView still satisfies the type system).
///
/// Hardcoded hex colors here are spec-mandated paper props:
/// - `#FFE680` — the yellow background, theme-independent so the sticky reads
///   the same on every paper theme.
/// - `#3A2A1A` — the warm brown body text, picked to feel like pen on yellow.
struct WeekStickyNote: View {
    /// Week relative to "now". Drives both the eyebrow icon/label and the
    /// body-text variant.
    let weekOffset: Int

    /// Pending Gmail suggestions for the week. When `weekOffset == 0` and
    /// this is `> 0`, the sticky flips to the "INBOX" variant.
    let inboxCount: Int

    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        if let body = Self.bodyText(for: weekOffset, inboxCount: inboxCount) {
            content(body: body)
        }
    }

    // MARK: - Subviews

    /// Full sticky rectangle: tape, eyebrow row, body text. Extracted so the
    /// top-level `body` can short-circuit to `EmptyView()` without dragging
    /// the rest of the rendering tree.
    private func content(body: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
                .padding(.bottom, 3)

            Text(body)
                .font(font.font(at: 13 * size.scale, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A2A1A"))
                .lineSpacing(1.15)
                .multilineTextAlignment(.leading)
        }
        .frame(width: 120, alignment: .leading)
        .padding(EdgeInsets(top: 9, leading: 10, bottom: 11, trailing: 10))
        .background(RoundedRectangle(cornerRadius: 1)
            .fill(Color(hex: "#FFE680")))
        .overlay(alignment: .top) {
            MaskingTape(width: .wide)
                .offset(y: -5)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
        .rotationEffect(.degrees(-3))
    }

    /// "INBOX" (with Gmail glyph) when current week has pending suggestions,
    /// otherwise "WEEK · AI" (with a sparkles glyph). Tiny system caps in
    /// 40% black, the same treatment as the day sticky's eyebrow.
    private var eyebrow: some View {
        HStack(spacing: 3) {
            if useInboxEyebrow {
                GmailGlyph(size: 9)
                Text("INBOX")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.black.opacity(0.4))
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.black.opacity(0.5))
                Text("WEEK · AI")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.black.opacity(0.4))
            }
        }
    }

    /// Convenience flag: the inbox eyebrow shows up only on the current week
    /// with at least one pending suggestion.
    private var useInboxEyebrow: Bool {
        weekOffset == 0 && inboxCount > 0
    }

    // MARK: - Body text mapping

    /// The one-line summary shown beneath the eyebrow, varying by week.
    /// Returns `nil` for weeks the spec leaves blank — `body` then collapses
    /// to `EmptyView()`. Static so tests can call it directly without
    /// instantiating the view.
    static func bodyText(for weekOffset: Int, inboxCount: Int) -> String? {
        if weekOffset == 0, inboxCount > 0 {
            return "\(inboxCount) new from Gmail — review \u{2198}"
        }
        switch weekOffset {
        case 0: return "Busiest Sat night — order Uber."
        case 1: return "NYC trip Fri-Sun. Pack Tue night."
        case 2: return "Memorial Day Mon — quiet week."
        case -1: return "Concert was the highlight!"
        default: return nil
        }
    }
}

// MARK: - Previews

#Preview("WeekStickyNote · This week, no inbox") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                WeekStickyNote(weekOffset: 0, inboxCount: 0)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("WeekStickyNote · This week, with inbox") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                WeekStickyNote(weekOffset: 0, inboxCount: 3)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("WeekStickyNote · NYC trip") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                WeekStickyNote(weekOffset: 1, inboxCount: 0)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
