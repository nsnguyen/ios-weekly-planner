import SwiftUI

/// Handwritten "+ add an event" link rendered inline at the bottom of
/// the Day page content, just above the page-number footer. Replaces
/// the earlier floating ink "+" FAB (which read as iOS chrome on the
/// otherwise paper-native page).
///
/// Visual recipe:
///   - Faint dashed rule above (`theme.ink3`, 0.5pt, 4-3 dash) acting
///     as a torn separator between the day's content and the action.
///   - Centered italic "+ add an event" in handwriting at 17pt × size
///     scale, blue ink, underlined — same affordance vocabulary as the
///     `EmptyDayState` add-task CTA so adds across the page read as a
///     consistent family.
///   - No card, no shadow, no border. It looks like the user wrote a
///     reminder to themselves at the bottom of the page.
struct AddEventLink: View {
    let onTap: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(spacing: 10) {
            DashedRule()
                .stroke(theme.ink3,
                        style: StrokeStyle(lineWidth: 0.5,
                                            lineCap: .round,
                                            dash: [4, 3]))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            Button(action: onTap) {
                Text("+ add an event")
                    .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                    .foregroundStyle(theme.blueInk)
                    .underline()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle().inset(by: -8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add an event")
            .accessibilityHint("Opens the new-event composer for this day")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("daypage.addEvent")
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
    }
}

/// Horizontal dashed line drawn at the vertical center of its frame.
/// Pulled into a `Shape` rather than a `Rectangle().border(...)` so the
/// `dash:` styling on `StrokeStyle` actually applies to a single
/// horizontal stroke instead of all four edges.
private struct DashedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Previews

#Preview("AddEventLink · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack {
                    Spacer()
                    AddEventLink(onTap: {})
                        .padding(.leading, 44)
                        .padding(.trailing, 18)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
