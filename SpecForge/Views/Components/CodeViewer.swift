import SwiftUI

struct CodeViewer: View {
    var file: GeneratedFile
    var onCopy: () -> Void

    @State private var didCopy = false

    private var lines: [String] {
        file.content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.editor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: fileIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack(spacing: 6) {
                Text(file.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text("\(file.lineCount) lines")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)

            Button {
                onCopy()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    didCopy = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.2)) {
                        didCopy = false
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text(didCopy ? "Copied" : "Copy")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(didCopy ? Theme.mint : Theme.textSecondary)
                .padding(.horizontal, 9)
                .frame(height: 27)
                .background(Theme.panelRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(didCopy ? Theme.mint.opacity(0.25) : Theme.stroke, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy file contents")
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background(Theme.backgroundRaised.opacity(0.62))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private var editor: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    CodeLine(
                        number: index + 1,
                        text: line,
                        isSwift: file.kind == .swift || file.kind == .manifest
                    )
                }
            }
            .padding(.vertical, 11)
            .fixedSize(horizontal: true, vertical: false)
        }
        .id(file.id)
        .scrollIndicators(.visible)
        .background(
            LinearGradient(
                colors: [Theme.editor, Color(hex: 0x080A0E)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var fileIcon: String {
        switch file.kind {
        case .manifest: return "shippingbox"
        case .markdown: return "doc.richtext"
        case .swift:
            return file.name == "JSONValue.swift" ? "curlybraces" : "swift"
        }
    }

    private var iconColor: Color {
        switch file.kind {
        case .manifest: return Theme.gold
        case .markdown: return Theme.sky
        case .swift: return Theme.accentBright
        }
    }
}

private struct CodeLine: View {
    var number: Int
    var text: String
    var isSwift: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text("\(number)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(number % 10 == 0 ? Theme.textSecondary.opacity(0.65) : Color(hex: 0x3B404D))
                .frame(width: 34, alignment: .trailing)
                .padding(.top, 1.5)

            Group {
                if isSwift {
                    Text(SwiftHighlighter.attributedLine(text.isEmpty ? " " : text))
                        .font(Theme.monoFont)
                        .textSelection(.enabled)
                } else {
                    Text(text.isEmpty ? " " : text)
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .frame(height: 19.5, alignment: .top)
    }
}
