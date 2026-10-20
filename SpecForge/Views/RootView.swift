import SwiftUI

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                titleBar
                ZStack {
                    if model.screen == .input {
                        InputView(model: model)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity
                            ))
                    } else {
                        ResultsView(model: model)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if model.isGenerating {
                LoadingOverlay(stage: model.generationStage)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.38, dampingFraction: 0.92), value: model.screen)
        .animation(.easeInOut(duration: 0.2), value: model.isGenerating)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(
                    toast: toast,
                    onReveal: {
                        model.revealLastExport()
                        model.dismissToast()
                    },
                    onDismiss: model.dismissToast
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: model.toast)
        .task {
            model.handleLaunchArguments()
        }
        .focusedSceneValue(\.appModel, model)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                BrandMark(size: 28)
                Text("SpecForge")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .tracking(-0.2)

                Text("OPENAPI → SWIFT")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.panelRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 18)
                .padding(.horizontal, 3)

            if model.screen == .results, let result = model.result {
                Text(result.metadata.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            } else {
                Text("New Swift client")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if model.screen == .results {
                SecondaryButton(title: "Edit spec", systemImage: "chevron.left") {
                    model.goToInput()
                }
                CompactExportButton {
                    model.export()
                }
            } else {
                HStack(spacing: 8) {
                    Text("v1.0")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)

                    SecondaryButton(title: "Open spec", systemImage: "folder") {
                        model.openSpecificationFile()
                    }
                }
            }
        }
        .padding(.leading, 86)
        .padding(.trailing, 22)
        .frame(height: 58)
        .background(
            ZStack {
                Theme.background.opacity(0.55)
                LinearGradient(
                    colors: [.white.opacity(0.025), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.stroke.opacity(0.7)).frame(height: 1)
        }
    }
}

private struct CompactExportButton: View {
    var action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text("Export")
                    .font(.system(size: 11.5, weight: .semibold))
                Text("⌘E")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentBright, Theme.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.accent.opacity(isHovering ? 0.45 : 0.25), radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

private struct LoadingOverlay: View {
    var stage: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.52))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.stroke, lineWidth: 1)
                        .frame(width: 54, height: 54)
                    ProgressView()
                        .controlSize(.regular)
                        .tint(Theme.accent)
                }

                VStack(spacing: 4) {
                    Text(stage.isEmpty ? "Generating Swift…" : stage)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Your API contract stays on this Mac.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 23)
            .frame(width: 310)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.panel.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 16)
        }
    }
}

private struct ToastView: View {
    var toast: AppModel.ToastMessage
    var onReveal: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mint)

            Text(toast.text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            if toast.revealURL != nil {
                Button("Show in Finder", action: onReveal)
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.panelRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, y: 8)
    }
}
