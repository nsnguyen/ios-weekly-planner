import SwiftUI

/// Gmail "M" envelope logo, ~22×16. Five fills approximating the official
/// Gmail mark — used inside the Connections row's 28pt logo slot. NOT an SF
/// Symbol (Gmail SF glyph is marketing-only per Apple HIG).
struct GmailBrandLogo: View {
    var size: CGSize = CGSize(width: 22, height: 16)

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Left red panel
            let leftPanel = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.25))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: w * 0.18, y: h))
                p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.45))
                p.closeSubpath()
            }
            context.fill(leftPanel, with: .color(Color(red: 0.91, green: 0.26, blue: 0.21)))

            // Right red panel
            let rightPanel = Path { p in
                p.move(to: CGPoint(x: w, y: h * 0.25))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w * 0.82, y: h))
                p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.45))
                p.closeSubpath()
            }
            context.fill(rightPanel, with: .color(Color(red: 0.91, green: 0.26, blue: 0.21)))

            // Inner red triangles (the "M" interior)
            let innerLeft = Path { p in
                p.move(to: CGPoint(x: w * 0.18, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.18, y: h))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.closeSubpath()
            }
            context.fill(innerLeft, with: .color(Color(red: 0.83, green: 0.18, blue: 0.18)))

            let innerRight = Path { p in
                p.move(to: CGPoint(x: w * 0.82, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.82, y: h))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.closeSubpath()
            }
            context.fill(innerRight, with: .color(Color(red: 0.83, green: 0.18, blue: 0.18)))

            // Top envelope flap (white over the panels)
            let flap = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.addLine(to: CGPoint(x: w, y: h * 0.25))
                p.addLine(to: CGPoint(x: w, y: h * 0.1))
                p.addLine(to: CGPoint(x: 0, y: h * 0.1))
                p.closeSubpath()
            }
            context.fill(flap, with: .color(.white))
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel("Gmail")
        .accessibilityAddTraits(.isImage)
    }
}

#Preview("GmailBrandLogo") {
    GmailBrandLogo().padding().background(.white)
}
