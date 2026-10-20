import SwiftUI

enum Theme {
    static let background = Color(hex: 0x090A0E)
    static let backgroundRaised = Color(hex: 0x0D0F15)
    static let panel = Color(hex: 0x12151D)
    static let panelRaised = Color(hex: 0x171B24)
    static let panelHover = Color(hex: 0x1C202B)
    static let editor = Color(hex: 0x0A0C11)
    static let stroke = Color.white.opacity(0.08)
    static let strokeStrong = Color.white.opacity(0.14)
    static let textPrimary = Color(hex: 0xF4F1EA)
    static let textSecondary = Color(hex: 0x9CA3B4)
    static let textTertiary = Color(hex: 0x6C7385)
    static let accent = Color(hex: 0xFF6B3D)
    static let accentBright = Color(hex: 0xFF8A5E)
    static let accentDeep = Color(hex: 0xE85024)
    static let mint = Color(hex: 0x8BE9A4)
    static let sky = Color(hex: 0x7CC7FF)
    static let gold = Color(hex: 0xF4C95D)
    static let danger = Color(hex: 0xFF6B6B)

    static let cornerRadius: CGFloat = 18
    static let smallRadius: CGFloat = 11

    static let uiFont = Font.system(size: 13, weight: .regular, design: .default)
    static let monoFont = Font.system(size: 12.5, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 11.5, weight: .regular, design: .monospaced)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func cardSurface(
        radius: CGFloat = Theme.cornerRadius,
        fill: Color = Theme.panel,
        border: Color = Theme.stroke
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct DotGrid: View {
    var opacity: Double = 0.35
    var spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.4, height: 1.4))
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(dot.offsetBy(dx: x, dy: y), with: .color(.white.opacity(opacity)))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
        .mask(
            LinearGradient(
                colors: [.white, .white.opacity(0.25), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Theme.background

            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: UnitPoint(x: 0.16, y: 0.02),
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [Theme.sky.opacity(0.06), .clear],
                center: UnitPoint(x: 0.92, y: 0.94),
                startRadius: 0,
                endRadius: 620
            )

            DotGrid(opacity: 0.12, spacing: 28)
                .frame(maxHeight: 420)
                .frame(maxHeight: .infinity, alignment: .top)
                .opacity(0.7)
        }
        .ignoresSafeArea()
    }
}
