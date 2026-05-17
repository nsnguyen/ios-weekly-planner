import SwiftUI

/// Visual gallery of every Phase 05 primitive. Lives only in `#Preview` blocks —
/// no production screen ever instantiates this view. The point is to give a
/// developer one Xcode canvas where they can scroll past every paper atom in
/// every theme and verify it still matches `docs/mock/paper-planner.jsx`.
///
/// Sections, in order:
/// 1. Book chrome — a half-height `BookCover` + `BookPage` showcase so the
///    leather + spine + edge stripes + binding shadow can be inspected without
///    any paper-surface decoration competing for attention.
/// 2. Paper surface internals — `PaperSurface` with `PaperGrain`, `RuledLines`,
///    `RedMarginLine`, and `HolePunches` layered inside. No event content yet —
///    just the empty page so the paper internals read clearly.
/// 3. Decorations — `WavyUnderline`, `DashedBorder`, `MaskingTape` (compact +
///    wide), `TornEdgeShape`.
/// 4. `InkShimmerText` — the "Thinking…" affordance.
/// 5. Controls — `PaperToggle` (compact / regular, off / on) and
///    `PaperPillButton` (primary / secondary, compact / regular).
/// 6. `PageNumber` — the day-page footer string.
///
/// Three `#Preview` blocks at the bottom of this file render the gallery under
/// `.cream`, `.kraft`, and `.midnight` so a developer can tab through every
/// theme without touching code.
struct PrimitivesPreview: View {
    @Environment(\.paperTheme) private var theme

    /// Neutral grey backdrop. Each section paints over this so primitives that
    /// don't carry their own background read consistently across themes.
    private static let backdrop = Color(white: 0.92)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                bookChromeSection
                paperSurfaceInternalsSection
                decorationsSection
                inkShimmerSection
                controlsSection
                pageNumberSection
            }
            .padding(20)
        }
        .background(Self.backdrop.ignoresSafeArea())
    }

    // MARK: - Sections

    /// Half-height showcase of `BookCover` + `BookPage` wrapping a plain
    /// `PaperSurface`. No paper internals — chrome only.
    private var bookChromeSection: some View {
        section(title: "Book chrome") {
            ZStack {
                BookCover()
                BookPage {
                    PaperSurface {
                        Color.clear
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 30)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// Single `BookPage` with every paper-surface decoration layered inside —
    /// no event content yet. Lets a developer eyeball the ruled grid, red
    /// margin, hole punches, and grain side by side.
    private var paperSurfaceInternalsSection: some View {
        section(title: "Paper surface internals") {
            ZStack {
                BookCover()
                BookPage {
                    PaperSurface {
                        ZStack {
                            PaperGrain()
                            RuledLines()
                            RedMarginLine()
                            HolePunches()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 30)
            }
            .frame(height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// Wavy underline, dashed border, masking tape (both widths), and a torn-
    /// edge sample, side by side on the neutral grey backdrop.
    private var decorationsSection: some View {
        section(title: "Decorations") {
            VStack(alignment: .leading, spacing: 20) {
                Text("To-do")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .wavyUnderline(color: theme.blueInk.opacity(0.3))

                Text("Today")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .foregroundStyle(theme.ink)
                    .dashedBorder(color: theme.ink3)

                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        MaskingTape(width: .compact)
                        Text("compact")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.ink3)
                    }
                    VStack(spacing: 6) {
                        MaskingTape(width: .wide)
                        Text("wide")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.ink3)
                    }
                }

                Rectangle()
                    .fill(theme.cream)
                    .frame(width: 160, height: 60)
                    .clipShape(TornEdgeShape())
                    .overlay {
                        TornEdgeShape()
                            .stroke(theme.ink3, lineWidth: 0.5)
                    }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.backdrop)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// Animated `InkShimmerText` on the neutral backdrop.
    private var inkShimmerSection: some View {
        section(title: "InkShimmerText") {
            InkShimmerText(text: "thinking…")
                .font(.system(size: 22, weight: .semibold))
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Self.backdrop)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// Toggles (compact off/on, regular off/on) followed by pill buttons
    /// (primary compact/regular, secondary compact/regular). The pill buttons
    /// sit on a strip of `BookCover` so the primary variant's leather-friendly
    /// blue + cream contrast can be inspected in context.
    private var controlsSection: some View {
        section(title: "Controls") {
            VStack(alignment: .leading, spacing: 20) {
                PaperTogglesRow()
                PaperPillButtonsRow()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.backdrop)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// The day-page footer string rendered alone on the neutral backdrop.
    private var pageNumberSection: some View {
        section(title: "PageNumber") {
            PageNumber(date: Date())
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(Self.backdrop)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Section header helper

    /// Wraps a body view in an uppercase 11pt bold `theme.ink3` header.
    private func section(title: String,
                         @ViewBuilder body: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(theme.ink3)
            body()
        }
    }
}

// MARK: - Local hosts (state needed for interactive controls)

/// Wires four `PaperToggle` instances to local `@State` so the slide
/// animation can be exercised inside the gallery preview.
private struct PaperTogglesRow: View {
    @State private var compactOff = false
    @State private var compactOn = true
    @State private var regularOff = false
    @State private var regularOn = true

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 12) {
                PaperToggle(isOn: $compactOff, style: .compact)
                PaperToggle(isOn: $compactOn, style: .compact)
            }
            VStack(spacing: 12) {
                PaperToggle(isOn: $regularOff, style: .regular)
                PaperToggle(isOn: $regularOn, style: .regular)
            }
        }
    }
}

/// Renders every `PaperPillButton` variant × size combination on a sliver of
/// `BookCover`. The leather strip is essential context: the primary pill is
/// designed to read against the dark cover, not the neutral page interior.
private struct PaperPillButtonsRow: View {
    @State private var lastTapped: String = ""

    var body: some View {
        ZStack {
            BookCover()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    PaperPillButton(title: "Today", variant: .primary, size: .compact) {
                        lastTapped = "primary-compact"
                    }
                    PaperPillButton(title: "Today", variant: .primary, size: .regular) {
                        lastTapped = "primary-regular"
                    }
                }
                HStack(spacing: 10) {
                    PaperPillButton(title: "Close", variant: .secondary, size: .compact) {
                        lastTapped = "secondary-compact"
                    }
                    PaperPillButton(title: "Close", variant: .secondary, size: .regular) {
                        lastTapped = "secondary-regular"
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview("Cream") {
    PrimitivesPreview()
        .paperTheme(.cream)
}

#Preview("Kraft") {
    PrimitivesPreview()
        .paperTheme(.kraft)
}

#Preview("Midnight") {
    PrimitivesPreview()
        .paperTheme(.midnight)
}
