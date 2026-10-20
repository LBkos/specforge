import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accentBright, Theme.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(.white.opacity(0.24), lineWidth: 0.8)
                )
                .shadow(color: Theme.accent.opacity(0.32), radius: size * 0.45, y: size * 0.1)

            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.46, weight: .black))
                .foregroundStyle(.white)
                .offset(y: -0.5)
        }
        .frame(width: size, height: size)
    }
}

struct ProminentButton: View {
    var title: String
    var systemImage: String? = "sparkles"
    var trailingHint: String?
    var isEnabled = true
    var isLoading = false
    var fillWidth = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if let trailingHint, !isLoading {
                    Text(trailingHint)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Theme.accentBright, Theme.accent]
                                : [Color(hex: 0x343841), Color(hex: 0x2C3038)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(.white.opacity(isEnabled ? 0.2 : 0.06), lineWidth: 1)
                    )
                    .shadow(
                        color: isEnabled ? Theme.accent.opacity(isHovering ? 0.45 : 0.25) : .clear,
                        radius: isHovering ? 18 : 11,
                        y: 5
                    )
            )
            .scaleEffect(isHovering && isEnabled ? 1.01 : 1)
            .opacity(isEnabled ? 1 : 0.7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
    }
}

struct SecondaryButton: View {
    var title: String
    var systemImage: String?
    var isDisabled = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(isHovering ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isHovering ? Theme.panelHover : Theme.panelRaised.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isHovering ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
    }
}

struct CompactIconButton: View {
    var systemImage: String
    var help: String
    var isActive = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? Theme.accent : (isHovering ? Theme.textPrimary : Theme.textSecondary))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Theme.panelHover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct MethodBadge: View {
    var method: String
    var compact = false

    private var color: Color {
        switch method.uppercased() {
        case "GET": return Theme.mint
        case "POST": return Theme.sky
        case "PUT": return Theme.gold
        case "PATCH": return Color(hex: 0xC7A2FF)
        case "DELETE": return Theme.danger
        default: return Theme.textSecondary
        }
    }

    var body: some View {
        Text(method.uppercased())
            .font(.system(size: compact ? 8.5 : 9, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 2.5 : 3.5)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(color.opacity(0.2), lineWidth: 0.7)
            )
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.25)
            .foregroundStyle(Theme.textTertiary)
    }
}

struct SoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
    }
}
