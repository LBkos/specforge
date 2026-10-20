import SwiftUI

struct ResultsView: View {
    @Bindable var model: AppModel
    @State private var isWarningsPresented = false

    var body: some View {
        if let result = model.result {
            VStack(spacing: 16) {
                summary(result: result)
                HStack(alignment: .top, spacing: 14) {
                    sidebar(result: result)
                        .frame(width: 252)
                    editor
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("No generated output yet.")
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func summary(result: GenerationResult) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.26), lineWidth: 1)
                Text(initials(for: result.metadata.title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentBright)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(result.metadata.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text("v\(result.metadata.version)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: 5))
                }

                HStack(spacing: 8) {
                    Text(result.metadata.specificationVersion)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)

                    Circle().fill(Theme.textTertiary.opacity(0.4)).frame(width: 2.5, height: 2.5)

                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 8.5))
                        Text(result.metadata.baseURL)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 8) {
                MetricTile(
                    value: "\(result.modelCount)",
                    label: "Types",
                    systemImage: "cube.transparent",
                    tint: Theme.sky
                )
                MetricTile(
                    value: "\(result.endpointCount)",
                    label: "Endpoints",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: Theme.mint
                )
                MetricTile(
                    value: "\(result.files.count)",
                    label: "Files",
                    systemImage: "doc.on.doc",
                    tint: Theme.gold
                )
                Button {
                    if !result.warnings.isEmpty {
                        isWarningsPresented.toggle()
                    }
                } label: {
                    MetricTile(
                        value: "\(result.warnings.count)",
                        label: result.warnings.count == 1 ? "Notice" : "Notices",
                        systemImage: result.warnings.isEmpty ? "checkmark.seal" : "exclamationmark.triangle",
                        tint: result.warnings.isEmpty ? Theme.mint : Theme.gold
                    )
                }
                .buttonStyle(.plain)
                .disabled(result.warnings.isEmpty)
                .help(result.warnings.isEmpty ? "No generation notices" : "View generation notices")
                .popover(isPresented: $isWarningsPresented, arrowEdge: .bottom) {
                    WarningsPopover(warnings: result.warnings)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardSurface(fill: Theme.panel.opacity(0.78))
    }

    private func sidebar(result: GenerationResult) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(AppModel.SidebarTab.allCases) { tab in
                    let isSelected = model.sidebarTab == tab
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            model.sidebarTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 27)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? Theme.panelHover : .clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(12)

            if model.sidebarTab == .files {
                fileList(result: result)
            } else {
                endpointList(result: result)
            }

            SoftDivider()

            HStack(spacing: 8) {
                Image(systemName: result.metadata.packageName.isEmpty ? "doc" : "shippingbox")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.packageName)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Text("⌘E to export")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
        }
        .frame(maxHeight: .infinity)
        .cardSurface()
    }

    private func fileList(result: GenerationResult) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 4) {
                let manifests = result.files.filter { $0.kind == .manifest }
                let sources = result.files.filter { $0.kind == .swift }
                let docs = result.files.filter { $0.kind == .markdown }

                if !manifests.isEmpty {
                    SidebarGroupLabel(text: "Package")
                    ForEach(manifests) { file in
                        FileRow(file: file, isSelected: model.selectedFilePath == file.id) {
                            model.selectFile(file)
                        }
                    }
                }

                if !sources.isEmpty {
                    SidebarGroupLabel(text: sourceGroupLabel(for: sources))
                        .padding(.top, manifests.isEmpty ? 0 : 8)
                    ForEach(sources) { file in
                        FileRow(file: file, isSelected: model.selectedFilePath == file.id) {
                            model.selectFile(file)
                        }
                    }
                }

                if !docs.isEmpty {
                    SidebarGroupLabel(text: "Documentation")
                        .padding(.top, 8)
                    ForEach(docs) { file in
                        FileRow(file: file, isSelected: model.selectedFilePath == file.id) {
                            model.selectFile(file)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    private func endpointList(result: GenerationResult) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 3) {
                if result.endpoints.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 20))
                        Text("No endpoints")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)
                } else {
                    HStack {
                        SectionLabel(text: "\(result.endpoints.count) Operations")
                        Spacer()
                        Text("path · method")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.bottom, 4)

                    ForEach(result.endpoints) { endpoint in
                        Button {
                            if let file = result.files.first(where: { $0.name == "Endpoints.swift" }) {
                                model.selectFile(file)
                                model.sidebarTab = .files
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    MethodBadge(method: endpoint.method, compact: true)
                                    Text(endpoint.functionName)
                                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                Text(endpoint.path)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Theme.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.panelRaised.opacity(0.45))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Show the file that contains \(endpoint.functionName)")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var editor: some View {
        if let file = model.selectedFile {
            CodeViewer(file: file) {
                model.copySelectedFile()
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                Text("Select a file to preview")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardSurface(fill: Theme.editor)
        }
    }

    private func sourceGroupLabel(for files: [GeneratedFile]) -> String {
        files.contains { $0.path.hasPrefix("Sources/") } ? "Swift Sources" : "Generated Files"
    }

    private func initials(for title: String) -> String {
        let words = title.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
        let letters = words.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "API" : result
    }
}

private struct SidebarGroupLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

private struct FileRow: View {
    var file: GeneratedFile
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.accentBright : Theme.textTertiary)
                    .frame(width: 16)

                Text(file.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text("\(file.lineCount)")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary.opacity(isSelected ? 0.9 : 0.65))
            }
            .padding(.horizontal, 9)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.1) : (isHovering ? Theme.panelHover.opacity(0.7) : .clear))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.accent)
                        .frame(width: 2, height: 14)
                        .padding(.leading, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var icon: String {
        switch file.kind {
        case .manifest: return "shippingbox"
        case .markdown: return "doc.richtext"
        case .swift:
            return file.name == "JSONValue.swift" ? "curlybraces" : "swift"
        }
    }
}

private struct MetricTile: View {
    var value: String
    var label: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .medium))
                Text(label)
                    .font(.system(size: 8.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint.opacity(0.9))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .frame(width: 84, height: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.backgroundRaised.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct WarningsPopover: View {
    var warnings: [GenerationWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generation notices")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(warnings.count) item\(warnings.count == 1 ? "" : "s") worth reviewing")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.gold)
            }
            .padding(14)

            SoftDivider()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(warnings) { warning in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: warning.severity == .info ? "info.circle" : "exclamationmark.triangle")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(warning.severity == .info ? Theme.sky : Theme.gold)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(warning.message)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let context = warning.context {
                                    Text(context)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Theme.textTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if warning.id != warnings.last?.id {
                            Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 35)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 350)
        .background(Theme.panel)
    }
}
