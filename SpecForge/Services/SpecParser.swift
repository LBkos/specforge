import Foundation
import Yams

enum SpecFormat: String, Sendable {
    case json
    case yaml
}

struct ParsedSpecification: Sendable {
    var value: SpecValue
    var format: SpecFormat
}

enum SpecParseError: LocalizedError {
    case empty
    case invalidJSON(String)
    case invalidYAML(String)
    case unsupportedRoot
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The specification is empty."
        case .invalidJSON(let message):
            return "The JSON could not be parsed. \(message)"
        case .invalidYAML(let message):
            return "The YAML could not be parsed. \(message)"
        case .unsupportedRoot:
            return "The specification's root value must be a JSON or YAML object."
        case .conversionFailed:
            return "The specification contains values that could not be read."
        }
    }
}

enum SpecParser {
    static func parse(_ text: String) throws -> ParsedSpecification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpecParseError.empty }

        // JSON is the primary input format. Trying it first produces more useful
        // diagnostics and avoids converting a perfectly valid JSON document
        // through the YAML decoder.
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            do {
                let object = try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
                guard let converted = SpecValue.from(any: object), converted.objectValue != nil else {
                    throw SpecParseError.unsupportedRoot
                }
                return ParsedSpecification(value: converted, format: .json)
            } catch let error as SpecParseError {
                throw error
            } catch {
                // A document starting with "{" is almost always JSON. Still allow
                // YAML flow mappings as a fallback below.
            }
        }

        do {
            if let object = try Yams.load(yaml: trimmed) {
                guard let converted = SpecValue.from(any: object), converted.objectValue != nil else {
                    throw SpecParseError.unsupportedRoot
                }
                return ParsedSpecification(value: converted, format: .yaml)
            }
            throw SpecParseError.empty
        } catch let error as SpecParseError {
            throw error
        } catch {
            throw SpecParseError.invalidYAML(error.localizedDescription)
        }
    }

    static func parse(data: Data) throws -> ParsedSpecification {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else {
            throw SpecParseError.conversionFailed
        }
        return try parse(text)
    }
}
