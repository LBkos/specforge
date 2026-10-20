import AppKit
import Foundation

enum ExportServiceError: LocalizedError {
    case unreadableFile
    case fileTooLarge
    case cannotCreateFolder(String)
    case cannotWriteFile(String, String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected file could not be read as text."
        case .fileTooLarge:
            return "Specification files are limited to 20 MB."
        case .cannotCreateFolder(let path):
            return "Could not create the output folder at \(path)."
        case .cannotWriteFile(let name, let message):
            return "Could not write \(name). \(message)"
        }
    }
}

@MainActor
enum ExportService {
    static func chooseDestinationAndExport(result: GenerationResult) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Export Swift Client"
        panel.message = "Choose where SpecForge should create the “\(result.packageName)” folder."
        panel.prompt = "Export Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let parent = panel.url else {
            return nil
        }

        let folder = uniqueFolder(named: result.packageName, in: parent)
        try write(result: result, to: folder)
        return folder
    }

    static func write(result: GenerationResult, to folder: URL) throws {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw ExportServiceError.cannotCreateFolder(folder.path)
        }

        for file in result.files {
            let destination = folder.appendingPathComponent(file.path)
            do {
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try file.content.write(to: destination, atomically: true, encoding: .utf8)
            } catch {
                throw ExportServiceError.cannotWriteFile(file.path, error.localizedDescription)
            }
        }
    }

    private static func uniqueFolder(named name: String, in parent: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(name) \(suffix)", isDirectory: true)
            suffix += 1
        }
        return candidate
    }
}
