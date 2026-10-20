import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable {
        case input
        case results
    }

    enum SidebarTab: String, CaseIterable, Identifiable {
        case files
        case endpoints

        var id: String { rawValue }

        var title: String {
            switch self {
            case .files: return "Files"
            case .endpoints: return "Endpoints"
            }
        }
    }

    struct ToastMessage: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var systemImage: String = "checkmark.circle.fill"
        var revealURL: URL?
    }

    var screen: Screen = .input
    var sourceMode: SpecSourceMode = .url
    var specURL = ""
    var pastedSpec = ""
    var loadedFile: LoadedSpecFile?
    var auth = AuthConfiguration()
    var options = GeneratorOptions()

    var isGenerating = false
    var generationStage = ""
    var errorMessage: String?
    var result: GenerationResult?
    var selectedFilePath: String?
    var sidebarTab: SidebarTab = .files
    var toast: ToastMessage?

    private var generationTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var didHandleLaunchArguments = false

    var selectedFile: GeneratedFile? {
        guard let result, let selectedFilePath else { return nil }
        return result.files.first { $0.id == selectedFilePath }
    }

    var canGenerate: Bool {
        guard !isGenerating else { return false }
        switch sourceMode {
        case .url:
            return !specURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .paste:
            return !pastedSpec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file:
            return loadedFile != nil
        }
    }

    var sourceSummary: String {
        switch sourceMode {
        case .url:
            return specURL.isEmpty ? "No URL yet" : specURL
        case .paste:
            return pastedSpec.isEmpty ? "Nothing pasted" : "\(pastedSpec.count.formatted()) characters"
        case .file:
            return loadedFile?.name ?? "No file selected"
        }
    }

    func generate() {
        guard !isGenerating else { return }
        errorMessage = nil

        let request: (source: String, label: String)
        switch sourceMode {
        case .url:
            let trimmed = specURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                errorMessage = "Enter the URL of an OpenAPI or Swagger document."
                return
            }
            if let message = auth.validationMessage {
                errorMessage = message
                return
            }
            request = (trimmed, trimmed)
        case .paste:
            guard !pastedSpec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Paste an OpenAPI document before generating."
                return
            }
            request = (pastedSpec, "Pasted specification")
        case .file:
            guard let loadedFile else {
                errorMessage = "Choose a specification file before generating."
                return
            }
            request = (loadedFile.text, loadedFile.name)
        }

        generationTask?.cancel()
        isGenerating = true
        generationStage = sourceMode == .url ? "Connecting to the specification…" : "Reading the specification…"

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                var text = request.source
                var sourceLabel = request.label

                if sourceMode == .url {
                    let fetched = try await SpecFetcher.fetch(urlString: request.source, auth: auth)
                    if Task.isCancelled { throw CancellationError() }
                    text = fetched.text
                    sourceLabel = fetched.finalURL?.absoluteString ?? request.source
                    generationStage = "Specification received. Parsing…"
                } else {
                    generationStage = "Parsing the specification…"
                }

                let options = self.options
                generationStage = "Forging Swift models and endpoints…"

                let generated = try await Task.detached(priority: .userInitiated) {
                    let parsed = try SpecParser.parse(text)
                    return try SwiftGenerator.generate(
                        parsed: parsed,
                        options: options,
                        sourceLabel: sourceLabel
                    )
                }.value

                if Task.isCancelled { throw CancellationError() }

                withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                    result = generated
                    selectedFilePath = generated.primaryFile?.id
                    sidebarTab = .files
                    screen = .results
                    isGenerating = false
                    generationStage = ""
                }
                generationTask = nil
            } catch is CancellationError {
                isGenerating = false
                generationStage = ""
            } catch {
                isGenerating = false
                generationStage = ""
                errorMessage = error.localizedDescription
                generationTask = nil
            }
        }
    }

    func handleLaunchArguments() {
        guard !didHandleLaunchArguments else { return }
        didHandleLaunchArguments = true
        if ProcessInfo.processInfo.arguments.contains("--example") {
            loadExample()
        }
    }

    func loadExample() {
        guard let url = Bundle.main.url(forResource: "ExampleSpec", withExtension: "json") else {
            errorMessage = "The bundled example specification could not be found."
            return
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            sourceMode = .paste
            pastedSpec = text
            loadedFile = nil
            errorMessage = nil
            generate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSpecificationFile() {
        let panel = NSOpenPanel()
        panel.title = "Open API Specification"
        panel.message = "Choose an OpenAPI 3.x or Swagger 2.0 document."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.json]
        if let yaml = UTType(filenameExtension: "yaml") {
            types.append(yaml)
        }
        if let yml = UTType(filenameExtension: "yml") {
            types.append(yml)
        }
        types.append(.plainText)
        panel.allowedContentTypes = types

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(url: url)
    }

    func loadFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 20 * 1024 * 1024 else {
                throw ExportServiceError.fileTooLarge
            }
            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
            else {
                throw ExportServiceError.unreadableFile
            }
            sourceMode = .file
            loadedFile = LoadedSpecFile(name: url.lastPathComponent, text: text)
            errorMessage = nil
            generate()
        } catch {
            errorMessage = "Could not read “\(url.lastPathComponent)”. \(error.localizedDescription)"
        }
    }

    func goToInput() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.92)) {
            screen = .input
        }
    }

    func selectFile(_ file: GeneratedFile) {
        selectedFilePath = file.id
    }

    func copySelectedFile() {
        guard let file = selectedFile else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.content, forType: .string)
        showToast("Copied \(file.name)", systemImage: "doc.on.doc.fill")
    }

    func export() {
        guard let result else { return }
        do {
            guard let folder = try ExportService.chooseDestinationAndExport(result: result) else {
                return
            }
            showToast(
                "Exported \(result.packageName)",
                systemImage: "checkmark.circle.fill",
                revealURL: folder
            )
        } catch {
            errorMessage = error.localizedDescription
            showToast("Export failed", systemImage: "exclamationmark.triangle.fill")
        }
    }

    func revealLastExport() {
        guard let url = toast?.revealURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func showToast(_ text: String, systemImage: String, revealURL: URL? = nil) {
        toastTask?.cancel()
        let message = ToastMessage(text: text, systemImage: systemImage, revealURL: revealURL)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            toast = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(revealURL == nil ? 2.6 : 5))
            guard !Task.isCancelled else { return }
            guard self?.toast?.id == message.id else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self?.toast = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toast = nil
        }
    }

    func dismissError() {
        withAnimation(.easeOut(duration: 0.2)) {
            errorMessage = nil
        }
    }
}
