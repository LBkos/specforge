import Foundation

/// A format-agnostic representation of a decoded JSON or YAML document.
///
/// OpenAPI documents mix arrays, objects, numbers, and booleans freely. Keeping
/// values in this small enum avoids unsafe `Any` casting throughout the
/// generator while preserving integer precision.
enum SpecValue: Sendable, Equatable {
    case object([String: SpecValue])
    case array([SpecValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    var objectValue: [String: SpecValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [SpecValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        switch self {
        case .integer(let value):
            return Int(exactly: value)
        case .number(let value):
            return Int(exactly: value)
        default:
            return nil
        }
    }

    var int64Value: Int64? {
        switch self {
        case .integer(let value):
            return value
        case .number(let value):
            return Int64(exactly: value)
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .integer(let value):
            return Double(value)
        case .number(let value):
            return value
        default:
            return nil
        }
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var stringArrayValue: [String]? {
        arrayValue?.compactMap(\.stringValue)
    }

    subscript(key: String) -> SpecValue? {
        objectValue?[key]
    }

    /// Converts loosely typed parser output into a `SpecValue`.
    static func from(any value: Any) -> SpecValue? {
        switch value {
        case is NSNull:
            return .null
        case let value as String:
            return .string(value)
        case let value as NSNumber:
            // NSNumber must be tested before Bool, Int, and Double because Swift
            // bridges those native values to NSNumber. CFBoolean identifies true
            // booleans without treating numeric 1 and 0 as booleans.
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            let double = value.doubleValue
            if let integer = value as? Int64, Double(integer) == double {
                return .integer(integer)
            }
            return .number(double)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .integer(Int64(value))
        case let value as Int64:
            return .integer(value)
        case let value as UInt:
            guard let signed = Int64(exactly: value) else { return .number(Double(value)) }
            return .integer(signed)
        case let value as Double:
            return .number(value)
        case let value as Float:
            return .number(Double(value))
        case let value as [Any]:
            let converted = value.compactMap(SpecValue.from(any:))
            guard converted.count == value.count else { return nil }
            return .array(converted)
        case let value as [String: Any]:
            var converted: [String: SpecValue] = [:]
            converted.reserveCapacity(value.count)
            for (key, child) in value {
                guard let child = SpecValue.from(any: child) else { return nil }
                converted[key] = child
            }
            return .object(converted)
        case let value as [AnyHashable: Any]:
            var converted: [String: SpecValue] = [:]
            for (key, child) in value {
                guard let key = key as? String, let child = SpecValue.from(any: child) else {
                    return nil
                }
                converted[key] = child
            }
            return .object(converted)
        default:
            return nil
        }
    }

    var compactDescription: String {
        switch self {
        case .object:
            return "object"
        case .array:
            return "array"
        case .string:
            return "string"
        case .integer:
            return "integer"
        case .number:
            return "number"
        case .bool:
            return "boolean"
        case .null:
            return "null"
        }
    }
}
