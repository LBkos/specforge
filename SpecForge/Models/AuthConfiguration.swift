import Foundation

struct AuthConfiguration: Equatable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case none
        case bearer
        case apiKey
        case basic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return "None"
            case .bearer: return "Bearer token"
            case .apiKey: return "API key"
            case .basic: return "Basic auth"
            }
        }
    }

    enum APIKeyLocation: String, CaseIterable, Identifiable, Sendable {
        case header
        case query

        var id: String { rawValue }

        var title: String {
            switch self {
            case .header: return "Header"
            case .query: return "Query"
            }
        }
    }

    var kind: Kind = .none
    var bearerToken = ""
    var apiKeyName = "X-API-Key"
    var apiKeyValue = ""
    var apiKeyLocation: APIKeyLocation = .header
    var username = ""
    var password = ""

    var isConfigured: Bool {
        switch kind {
        case .none:
            return true
        case .bearer:
            return !bearerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .apiKey:
            return !apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .basic:
            return !username.isEmpty && !password.isEmpty
        }
    }

    var validationMessage: String? {
        guard !isConfigured else { return nil }
        switch kind {
        case .none:
            return nil
        case .bearer:
            return "Enter a bearer token to fetch this specification."
        case .apiKey:
            return "Enter both an API key name and value."
        case .basic:
            return "Enter both a username and password."
        }
    }

    var summary: String {
        switch kind {
        case .none: return "No authentication"
        case .bearer: return "Bearer token"
        case .apiKey: return "API key · \(apiKeyName)"
        case .basic: return "Basic authentication"
        }
    }
}

struct LoadedSpecFile: Equatable, Sendable {
    var name: String
    var text: String
}

enum SpecSourceMode: String, CaseIterable, Identifiable, Sendable {
    case url
    case paste
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .url: return "URL"
        case .paste: return "Paste"
        case .file: return "File"
        }
    }
}
