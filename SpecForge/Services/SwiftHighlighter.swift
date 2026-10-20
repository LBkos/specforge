import SwiftUI

enum SwiftHighlighter {
    private static let keywords: Set<String> = [
        "actor", "any", "as", "associatedtype", "async", "await", "break", "case",
        "catch", "class", "continue", "convenience", "defer", "default", "deinit",
        "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate",
        "final", "for", "func", "guard", "if", "import", "in", "indirect", "init",
        "inout", "internal", "is", "let", "mutating", "nil", "nonmutating",
        "open", "operator", "override", "private", "protocol", "public", "repeat",
        "required", "return", "self", "Self", "static", "struct", "subscript",
        "super", "switch", "throw", "throws", "true", "try", "typealias", "var",
        "where", "while", "unowned", "weak", "some", "each", "package", "macro"
    ]

    private static let builtinTypes: Set<String> = [
        "String", "Int", "Int64", "Double", "Float", "Bool", "Date", "Data",
        "URL", "URLRequest", "URLSession", "URLQueryItem", "URLComponents",
        "JSONDecoder", "JSONEncoder", "ISO8601DateFormatter", "DateFormatter",
        "CharacterSet", "Locale", "TimeZone", "Error", "DecodingError",
        "Codable", "Encodable", "Decodable", "Sendable", "Equatable",
        "CaseIterable", "LocalizedError", "HTTPURLResponse", "URLResponse",
        "Void", "Optional", "Array", "Dictionary", "UUID", "Character"
    ]

    static func attributedLine(_ line: String) -> AttributedString {
        var output = AttributedString()
        let characters = Array(line)
        var index = 0
        var lastWord = ""

        func append(_ text: String, color: Color) {
            guard !text.isEmpty else { return }
            var piece = AttributedString(text)
            piece.foregroundColor = color
            output.append(piece)
        }

        while index < characters.count {
            let character = characters[index]

            if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                append(String(characters[index...]), color: Color(hex: 0x697386))
                break
            }

            if character == "\"" {
                var end = index + 1
                var escaped = false
                while end < characters.count {
                    let next = characters[end]
                    if next == "\"", !escaped { end += 1; break }
                    if next == "\\", !escaped {
                        escaped = true
                    } else {
                        escaped = false
                    }
                    end += 1
                }
                append(String(characters[index..<min(end, characters.count)]), color: Color(hex: 0xA8DB7E))
                index = end
                continue
            }

            if character == "@" {
                var end = index + 1
                while end < characters.count, characters[end].isLetter || characters[end] == "_" {
                    end += 1
                }
                append(String(characters[index..<end]), color: Theme.accentBright)
                index = end
                continue
            }

            if character.isNumber {
                var end = index + 1
                while end < characters.count,
                      characters[end].isNumber || characters[end] == "." || characters[end] == "x"
                        || (characters[end].isHexDigit && end > index + 1) {
                    end += 1
                }
                append(String(characters[index..<end]), color: Theme.gold)
                index = end
                continue
            }

            if character.isLetter || character == "_" {
                var end = index + 1
                while end < characters.count, characters[end].isLetter || characters[end].isNumber || characters[end] == "_" {
                    end += 1
                }
                let word = String(characters[index..<end])
                if keywords.contains(word) {
                    append(word, color: Color(hex: 0xFF7BA8))
                } else if builtinTypes.contains(word) || word.first?.isUppercase == true {
                    append(word, color: Theme.sky)
                } else if lastWord == "func" {
                    append(word, color: Theme.mint)
                } else {
                    append(word, color: Theme.textPrimary)
                }
                lastWord = word
                index = end
                continue
            }

            if character == "`" {
                var end = index + 1
                while end < characters.count, characters[end] != "`" { end += 1 }
                if end < characters.count { end += 1 }
                append(String(characters[index..<end]), color: Color(hex: 0xFFB86B))
                index = end
                continue
            }

            append(String(character), color: Color(hex: 0xB8BECC))
            index += 1
        }

        return output
    }
}
