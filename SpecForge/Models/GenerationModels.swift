import Foundation

enum AccessLevel: String, CaseIterable, Identifiable, Sendable {
    case `internal`
    case `public`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .internal: return "Internal"
        case .public: return "Public"
        }
    }

    var detail: String {
        switch self {
        case .internal: return "For use inside one app target"
        case .public: return "Expose a reusable API package"
        }
    }

    var swiftPrefix: String {
        self == .public ? "public " : ""
    }
}

enum DateMapping: String, CaseIterable, Identifiable, Sendable {
    case date
    case string

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: return "Date"
        case .string: return "String"
        }
    }
}

struct GeneratorOptions: Equatable, Sendable {
    var accessLevel: AccessLevel = .public
    var dateMapping: DateMapping = .date
    var typePrefix = ""
    var baseURLOverride = ""
    var includeReadme = true
    var includePackageManifest = true
}

struct SpecMetadata: Equatable, Sendable {
    var title: String
    var version: String
    var description: String
    var specificationVersion: String
    var baseURL: String
    var sourceLabel: String
    var packageName: String
}

struct GeneratedFile: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case swift
        case markdown
        case manifest
    }

    let path: String
    let content: String
    let kind: Kind

    var id: String { path }

    var name: String {
        (path as NSString).lastPathComponent
    }

    var directory: String {
        (path as NSString).deletingLastPathComponent
    }

    var lineCount: Int {
        content.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    var byteCount: Int {
        content.utf8.count
    }
}

struct GeneratedEndpoint: Identifiable, Hashable, Sendable {
    var method: String
    var path: String
    var functionName: String
    var summary: String
    var responseType: String
    var tag: String?

    var id: String { "\(method)-\(path)-\(functionName)" }
}

struct GenerationWarning: Identifiable, Hashable, Sendable {
    enum Severity: String, Hashable, Sendable {
        case info
        case warning
    }

    var id = UUID()
    var message: String
    var context: String?
    var severity: Severity = .warning
}

struct GenerationResult: Sendable {
    var files: [GeneratedFile]
    var endpoints: [GeneratedEndpoint]
    var warnings: [GenerationWarning]
    var metadata: SpecMetadata
    var modelCount: Int
    var endpointCount: Int
    var packageName: String

    var primaryFile: GeneratedFile? {
        files.first(where: { $0.name == "Models.swift" }) ?? files.first
    }

    var swiftFileCount: Int {
        files.filter { $0.kind == .swift }.count
    }
}

enum GeneratorError: LocalizedError {
    case unsupportedSpecification
    case missingSchemaSection
    case noContent

    var errorDescription: String? {
        switch self {
        case .unsupportedSpecification:
            return "This file is not an OpenAPI 3.x or Swagger 2.0 specification."
        case .missingSchemaSection:
            return "The specification does not contain a usable schema section."
        case .noContent:
            return "The specification is empty."
        }
    }
}
