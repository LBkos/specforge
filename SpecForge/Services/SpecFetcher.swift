import Foundation

struct FetchedSpecification: Sendable {
    var text: String
    var finalURL: URL?
    var contentType: String?
}

enum SpecFetchError: LocalizedError {
    case invalidURL(String)
    case missingCredentials(String)
    case unauthorized(Int)
    case httpStatus(Int)
    case emptyResponse
    case responseTooLarge
    case unreadableResponse
    case htmlResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "“\(value)” is not a valid HTTP or HTTPS URL."
        case .missingCredentials(let message):
            return message
        case .unauthorized(let code):
            return "The server returned \(code). Check the authentication details and try again."
        case .httpStatus(let code):
            return "The specification URL returned HTTP \(code)."
        case .emptyResponse:
            return "The server returned an empty response."
        case .responseTooLarge:
            return "The specification is larger than 20 MB."
        case .unreadableResponse:
            return "The response could not be decoded as text."
        case .htmlResponse:
            return "The URL returned an HTML page instead of an OpenAPI document. Use the direct JSON or YAML specification URL."
        case .transport(let message):
            return "Could not reach the specification URL. \(message)"
        }
    }
}

enum SpecFetcher {
    static func fetch(urlString: String, auth: AuthConfiguration) async throws -> FetchedSpecification {
        if let message = auth.validationMessage {
            throw SpecFetchError.missingCredentials(message)
        }

        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw SpecFetchError.invalidURL(urlString)
        }
        if !normalized.lowercased().hasPrefix("http://")
            && !normalized.lowercased().hasPrefix("https://") {
            normalized = "https://" + normalized
        }

        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil
        else {
            throw SpecFetchError.invalidURL(urlString)
        }

        if auth.kind == .apiKey, auth.apiKeyLocation == .query {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(
                name: auth.apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines),
                value: auth.apiKeyValue
            ))
            components.queryItems = items
        }

        guard let url = components.url else {
            throw SpecFetchError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(
            "application/json, application/yaml, text/yaml, application/x-yaml, text/plain, */*",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("SpecForge/1.0", forHTTPHeaderField: "User-Agent")

        switch auth.kind {
        case .none:
            break
        case .bearer:
            let token = auth.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            if auth.apiKeyLocation == .header {
                request.setValue(
                    auth.apiKeyValue,
                    forHTTPHeaderField: auth.apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        case .basic:
            let credentials = "\(auth.username):\(auth.password)"
            let encoded = Data(credentials.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw SpecFetchError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpecFetchError.transport("No HTTP response was returned.")
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw SpecFetchError.unauthorized(http.statusCode)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SpecFetchError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw SpecFetchError.emptyResponse
        }
        guard data.count <= 20 * 1024 * 1024 else {
            throw SpecFetchError.responseTooLarge
        }
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            throw SpecFetchError.unreadableResponse
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if contentType?.contains("text/html") == true
            || trimmed.hasPrefix("<!doctype html")
            || trimmed.hasPrefix("<html") {
            throw SpecFetchError.htmlResponse
        }

        return FetchedSpecification(
            text: text,
            finalURL: http.url,
            contentType: http.value(forHTTPHeaderField: "Content-Type")
        )
    }
}
