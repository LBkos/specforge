import Foundation

enum SwiftNaming {
    private static let initialisms: Set<String> = [
        "api", "url", "urls", "http", "https", "id", "uuid", "dto", "json",
        "xml", "html", "jwt", "oauth", "ip", "ui", "uri", "sdk", "cli",
        "ttl", "etag", "ios", "macos", "csv", "pdf", "sql"
    ]

    static let keywords: Set<String> = [
        "associatedtype", "borrowing", "class", "consuming", "deinit", "enum",
        "extension", "fileprivate", "func", "import", "init", "inout", "internal",
        "let", "macro", "open", "operator", "package", "precedencegroup", "private",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
        "var", "actor", "any", "as", "async", "await", "break", "case", "catch",
        "continue", "default", "defer", "do", "else", "fallthrough", "false", "for",
        "guard", "if", "in", "is", "nil", "repeat", "return", "self", "Self", "some",
        "super", "switch", "throw", "throws", "true", "try", "where", "while", "each",
        "sending", "sending", "nonisolated", "isolated", "mutating", "nonmutating",
        "override", "required", "convenience", "dynamic", "final", "lazy", "weak",
        "unowned", "indirect", "infix", "postfix", "prefix", "Type", "Protocol"
    ]

    static func words(in raw: String) -> [String] {
        var spaced = ""
        let characters = Array(raw)
        for index in characters.indices {
            let character = characters[index]
            if character.isLetter || character.isNumber {
                if index > characters.startIndex {
                    let previous = characters[index - 1]
                    let next = index + 1 < characters.endIndex ? characters[index + 1] : nil
                    let camelBoundary = previous.isLowercase && character.isUppercase
                    let acronymBoundary = previous.isUppercase
                        && character.isUppercase
                        && next?.isLowercase == true
                    if camelBoundary || acronymBoundary {
                        spaced.append(" ")
                    }
                }
                spaced.append(character)
            } else {
                spaced.append(" ")
            }
        }

        return spaced
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func pascal(_ raw: String) -> String {
        let parts = words(in: raw)
        guard !parts.isEmpty else { return "" }
        let joined = parts.map { part -> String in
            let lower = part.lowercased()
            if initialisms.contains(lower) {
                return lower.uppercased()
            }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined()

        guard let first = joined.first else { return "" }
        if first.isNumber {
            return "Model" + joined
        }
        return joined
    }

    static func camel(_ raw: String) -> String {
        let parts = words(in: raw)
        guard !parts.isEmpty else { return "" }

        var result = ""
        for (index, part) in parts.enumerated() {
            let lower = part.lowercased()
            if index == 0 {
                result += lower
            } else if initialisms.contains(lower) {
                result += lower.uppercased()
            } else {
                result += lower.prefix(1).uppercased() + lower.dropFirst()
            }
        }

        guard let first = result.first else { return "" }
        if first.isNumber {
            result = "value" + result.prefix(1).uppercased() + result.dropFirst()
        }
        return result
    }

    static func property(_ raw: String) -> String {
        escape(camel(raw).isEmpty ? "value" : camel(raw))
    }

    static func method(_ raw: String) -> String {
        escape(camel(raw).isEmpty ? "request" : camel(raw))
    }

    static func escape(_ identifier: String) -> String {
        keywords.contains(identifier) ? "`\(identifier)`" : identifier
    }

    static func enumCase(from raw: String, index: Int) -> String {
        let base = camel(raw)
        if base.isEmpty {
            return "case\(index + 1)"
        }
        if base.allSatisfy({ $0.isNumber || $0 == "-" }) {
            return "value\(base.replacingOccurrences(of: "-", with: "Minus"))"
        }
        return escape(base)
    }

    static func integerCase(_ value: Int64) -> String {
        if value < 0 {
            return "valueMinus\(value == Int64.min ? "Max" : String(value * -1))"
        }
        return "value\(value)"
    }

    static func stringLiteral(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            default:
                if scalar.value < 0x20 {
                    result += String(format: "\\u{%X}", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        result += "\""
        return result
    }

    static func commentLines(_ raw: String?) -> [String] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? "///" : "/// \(trimmed)"
            }
    }

    static func indent(_ block: String, by spaces: Int = 4) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : prefix + $0 }
            .joined(separator: "\n")
    }

    static func slug(_ raw: String) -> String {
        let value = camel(raw)
        return value.isEmpty ? "generated" : value
    }
}
