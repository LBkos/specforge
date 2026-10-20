import SwiftUI
import UniformTypeIdentifiers

struct InputView: View {
    @Bindable var model: AppModel
    @State private var isDropTargeted = false
    @State private var isAdvancedExpanded = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 26) {
                hero
                if let errorMessage = model.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        model.dismissError()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                HStack(alignment: .top, spacing: 18) {
                    sourceCard
                        .frame(maxWidth: .infinity)
                    settingsCard
                        .frame(width: 334)
                }
                footer
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.top, 20)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: model.errorMessage)
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: model.sourceMode)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.mint)
                    .frame(width: 5, height: 5)
                    .shadow(color: Theme.mint.opacity(0.8), radius: 4)
                Text("MACOS · OPENAPI → SWIFT")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Turn API specs into")
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 11) {
                    Text("Swift you can ship.")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accentBright, Color(hex: 0xFFB27E)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent.opacity(0.65))
                        .padding(.top, 8)
                }
            }
            .font(.system(size: 36, weight: .bold, design: .default))
            .tracking(-1.0)

            Text("Paste a spec, drop a file, or fetch one from a URL. Get Codable models, typed endpoints, and an async URLSession client — ready to build.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: 660, alignment: .leading)

            HStack(spacing: 18) {
                FeatureTag(systemImage: "cube.transparent", text: "Codable models")
                FeatureTag(systemImage: "bolt.horizontal", text: "Async/await endpoints")
                FeatureTag(systemImage: "shippingbox", text: "Swift package export")
            }
            .padding(.top, 2)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "API Specification")
                    Text("Where is your spec?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                    Text("JSON or YAML")
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            }

            SourceModeTabs(selection: $model.sourceMode)

            Group {
                switch model.sourceMode {
                case .url:
                    urlSource
                case .paste:
                    pasteSource
                case .file:
                    fileSource
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            Spacer(minLength: 4)

            outputPreview
        }
        .padding(19)
        .frame(maxWidth: .infinity, minHeight: 450, alignment: .top)
        .cardSurface()
    }

    private var urlSource: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Specification URL")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 9) {
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)

                    TextField("https://api.example.com/openapi.json", text: $model.specURL)
                        .textFieldStyle(.plain)
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.textPrimary)
                        .onSubmit { model.generate() }

                    if !model.specURL.isEmpty {
                        Button {
                            model.specURL = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear URL")
                    }

                    Text("GET")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.mint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 12)
                .frame(height: 43)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.backgroundRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(model.specURL.isEmpty ? Theme.stroke : Theme.strokeStrong, lineWidth: 1)
                )
            }

            AuthEditor(auth: $model.auth)

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 9.5))
                    Text("Private specs supported · localhost is fine")
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.textTertiary)

                Spacer()

                Button {
                    model.loadExample()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Load example")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.accentBright)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 1)
        }
    }

    private var pasteSource: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Paste an OpenAPI 3.x or Swagger 2.0 document")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    model.loadExample()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Use example")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.accentBright)
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.backgroundRaised)

                TextEditor(text: $model.pastedSpec)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 9)
                    .background(.clear)

                if model.pastedSpec.isEmpty {
                    Text("{\n  \"openapi\": \"3.0.0\",\n  ...\n}")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 284)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )

            HStack {
                Text(model.pastedSpec.isEmpty ? "Nothing pasted yet" : "\(model.pastedSpec.count.formatted()) characters")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                if !model.pastedSpec.isEmpty {
                    Button {
                        model.pastedSpec = ""
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var fileSource: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let file = model.loadedFile {
                VStack(spacing: 15) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.mint.opacity(0.1))
                            .frame(width: 62, height: 62)
                        Image(systemName: "doc.badge.checkmark")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(Theme.mint)
                    }

                    VStack(spacing: 4) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text("\(file.text.count.formatted()) characters · ready to generate")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    HStack(spacing: 9) {
                        SecondaryButton(title: "Choose another", systemImage: "arrow.triangle.2.circlepath") {
                            model.openSpecificationFile()
                        }
                        ProminentButton(
                            title: "Generate client",
                            systemImage: "sparkles",
                            isEnabled: !model.isGenerating,
                            isLoading: model.isGenerating
                        ) {
                            model.generate()
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 284)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.backgroundRaised.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.panelHover)
                            .frame(width: 62, height: 62)
                        Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "doc.text.magnifyingglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(isDropTargeted ? Theme.accent : Theme.textSecondary)
                    }

                    VStack(spacing: 5) {
                        Text(isDropTargeted ? "Drop it right here" : "Drop an OpenAPI file")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("JSON, YAML, or YML · up to 20 MB")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    SecondaryButton(title: "Choose file…", systemImage: "folder") {
                        model.openSpecificationFile()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 284)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDropTargeted ? Theme.accent.opacity(0.05) : Theme.backgroundRaised.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isDropTargeted ? Theme.accent.opacity(0.7) : Theme.strokeStrong,
                            style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                        )
                )
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    Task { @MainActor in
                        model.loadFile(url: url)
                    }
                    return true
                } isTargeted: { targeted in
                    withAnimation(.easeOut(duration: 0.16)) {
                        isDropTargeted = targeted
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8.5))
                Text("Files are read on-device; nothing is uploaded.")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(Theme.textTertiary)
        }
    }

    private var outputPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.gold)
                .frame(width: 26, height: 26)
                .background(Theme.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("A ready-to-build Swift package")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("Codable models · typed endpoints · async URLSession client")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(["Models", "Client", "API"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Theme.panelRaised.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.backgroundRaised.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "Generation")
                Text("Output settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Access level")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 7) {
                    ForEach(AccessLevel.allCases) { level in
                        AccessOption(
                            level: level,
                            isSelected: model.options.accessLevel == level
                        ) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                model.options.accessLevel = level
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Date fields")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker("Date fields", selection: $model.options.dateMapping) {
                    ForEach(DateMapping.allCases) { mapping in
                        Text(mapping.title).tag(mapping)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .frame(width: 142)
            }

            InputField(
                title: "Type prefix",
                placeholder: "e.g. ACME",
                systemImage: "textformat",
                text: $model.options.typePrefix,
                monospaced: true
            )

            VStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        isAdvancedExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Advanced")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(model.options.baseURLOverride.isEmpty ? "Base URL" : "Base URL set")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textTertiary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .rotationEffect(.degrees(isAdvancedExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.backgroundRaised.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isAdvancedExpanded {
                    InputField(
                        title: "Base URL override",
                        placeholder: "Use the spec's server",
                        systemImage: "link",
                        text: $model.options.baseURLOverride,
                        monospaced: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            VStack(spacing: 7) {
                SettingToggle(
                    title: "Include README",
                    subtitle: "Usage notes and endpoint table",
                    isOn: $model.options.includeReadme
                )
                SettingToggle(
                    title: "Swift Package",
                    subtitle: "Package.swift + Sources layout",
                    isOn: $model.options.includePackageManifest
                )
            }
            .padding(.top, 1)

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                ProminentButton(
                    title: model.isGenerating ? "Forging…" : "Generate Swift client",
                    systemImage: "sparkles",
                    trailingHint: "⌘↩",
                    isEnabled: model.canGenerate,
                    isLoading: model.isGenerating,
                    fillWidth: true
                ) {
                    model.generate()
                }
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal")
                    Text("Compilable Swift · async/await · Codable")
                }
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(19)
        .frame(minHeight: 450, alignment: .top)
        .cardSurface()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Works with")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)

            SpecBadge(text: "OpenAPI 3.0")
            SpecBadge(text: "OpenAPI 3.1")
            SpecBadge(text: "Swagger 2.0")

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "display")
                Text("Generated on-device")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 4)
    }
}

private struct FeatureTag: View {
    var systemImage: String
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.accentBright)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct SourceModeTabs: View {
    @Binding var selection: SpecSourceMode

    var body: some View {
        HStack(spacing: 3) {
            ForEach(SpecSourceMode.allCases) { mode in
                let isSelected = selection == mode
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Theme.panelHover : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isSelected ? Theme.stroke : .clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func icon(for mode: SpecSourceMode) -> String {
        switch mode {
        case .url: return "globe"
        case .paste: return "doc.on.clipboard"
        case .file: return "folder"
        }
    }
}

private struct AccessOption: View {
    var level: AccessLevel
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: level == .public ? "globe" : "lock")
                    .font(.system(size: 9.5, weight: .medium))
                Text(level.title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.09) : (isHovering ? Theme.panelHover : Theme.backgroundRaised))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.45) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(level.detail)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

private struct SettingToggle: View {
    var title: String
    var subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(Theme.accent)
                .scaleEffect(0.82)
                .frame(width: 30, height: 22)
        }
        .frame(height: 28)
    }
}

private struct SpecBadge: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Theme.stroke, lineWidth: 0.7)
            )
    }
}

private struct ErrorBanner: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn’t generate the client")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Theme.panelHover, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.danger.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.danger.opacity(0.22), lineWidth: 1)
        )
    }
}
