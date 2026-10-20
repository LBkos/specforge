import Foundation

enum SpecVersion: Sendable {
    case openAPI3(String)
    case swagger2

    var displayName: String {
        switch self {
        case .openAPI3(let version): return "OpenAPI \(version)"
        case .swagger2: return "Swagger 2.0"
        }
    }

    var schemaRefPrefix: String {
        switch self {
        case .openAPI3: return "#/components/schemas/"
        case .swagger2: return "#/definitions/"
        }
    }
}

struct ModelDefinition {
    enum Kind {
        case object
        case stringEnum
        case intEnum
        case union
        case alias
    }

    var name: String
    var schema: SpecValue
    var kind: Kind
    var sourceKey: String?
    var dependencies: Set<String> = []
    var isRecursive = false
}

struct ResolvedType {
    var swiftType: String
    var nullable = false
    var scalar: ScalarKind?
    var arrayElementType: String?
    var arrayElementScalar: ScalarKind?
    var dependencies: Set<String> = []

    var isArray: Bool { arrayElementType != nil }

    enum ScalarKind {
        case string
        case number
        case boolean
        case date
        case data
        case enumString
        case enumInt
        case object
        case json
    }

    func propertyType(optional: Bool) -> String {
        let needsOptional = optional || nullable
        return needsOptional && !swiftType.hasSuffix("?") ? swiftType + "?" : swiftType
    }
}

struct ObjectProperty {
    var jsonKey: String
    var swiftName: String
    var type: ResolvedType
    var isOptional: Bool
    var description: String?
    var isDeprecated: Bool

    var declarationType: String {
        type.propertyType(optional: isOptional)
    }
}

struct OperationParameter {
    enum Location: String {
        case path
        case query
        case header
    }

    var location: Location
    var jsonName: String
    var swiftName: String
    var type: ResolvedType
    var isRequired: Bool
    var description: String?
    var explode: Bool
}

struct OperationBody {
    var swiftName: String
    var type: ResolvedType
    var isRequired: Bool
    var contentType: String
}

struct OperationResponse {
    enum Kind {
        case json
        case text
        case data
        case empty
    }

    var kind: Kind
    var type: ResolvedType?
    var mediaType: String?

    var swiftTypeName: String {
        switch kind {
        case .empty: return "Void"
        case .text: return "String"
        case .data: return "Data"
        case .json: return type?.propertyType(optional: false) ?? "JSONValue"
        }
    }
}

struct OperationDefinition {
    var method: String
    var path: String
    var swiftName: String
    var summary: String
    var description: String?
    var tag: String?
    var isDeprecated: Bool
    var parameters: [OperationParameter]
    var body: OperationBody?
    var response: OperationResponse
}

final class GeneratorContext {
    let raw: SpecValue
    let root: [String: SpecValue]
    let options: GeneratorOptions
    let sourceLabel: String
    let specVersion: SpecVersion
    let schemas: [String: SpecValue]
    let apiTitle: String
    let apiVersion: String
    let apiDescription: String
    let baseURL: String
    let packageName: String

    private(set) var warnings: [GenerationWarning] = []
    private(set) var models: [String: ModelDefinition] = [:]
    private(set) var modelOrder: [String] = []
    private(set) var operations: [OperationDefinition] = []
    var usesJSONValue = false

    private var refToModelName: [String: String] = [:]
    private var usedTypeNames: Set<String> = []
    private var usedOperationNames: Set<String> = []
    private var warnedMessages: Set<String> = []
    private var typeCache: [String: ResolvedType] = [:]
    private var typesInProgress: Set<String> = []
    private var objectPropertiesCache: [String: [ObjectProperty]] = [:]
    private var effectiveSchemaCache: [String: [String: SpecValue]] = [:]

    private static let reservedTypeNames: Set<String> = [
        "APIClient", "APIAuth", "APIKeyLocation", "APIError", "HTTPMethod",
        "EmptyResponse", "JSONValue", "String", "Int", "Int64", "Double",
        "Float", "Bool", "Date", "Data", "URL", "URLRequest", "URLSession",
        "URLQueryItem", "Codable", "Encodable", "Decodable", "Optional",
        "Array", "Dictionary", "Error", "Foundation"
    ]

    private static let reservedOperationNames: Set<String> = [
        "send", "sendRaw", "sendEmpty", "perform", "makeURL", "pathComponent",
        "queryString", "shared", "init"
    ]

    private static let httpMethods = ["get", "post", "put", "patch", "delete", "head", "options", "trace"]

    init(parsed: ParsedSpecification, options: GeneratorOptions, sourceLabel: String) throws {
        guard let root = parsed.value.objectValue else {
            throw SpecParseError.unsupportedRoot
        }

        self.raw = parsed.value
        self.root = root
        self.options = options
        self.sourceLabel = sourceLabel
        self.specVersion = try Self.detectVersion(root)
        self.schemas = Self.findSchemas(root: root, version: specVersion)

        let info = root["info"]?.objectValue ?? [:]
        self.apiTitle = info["title"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "Untitled API"
        self.apiVersion = info["version"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "1.0.0"
        self.apiDescription = info["description"]?.stringValue ?? ""

        let resolvedBase = Self.resolveBaseURL(root: root, version: specVersion, options: options)
        self.baseURL = resolvedBase.url
        self.packageName = Self.makePackageName(from: apiTitle)
        if let warning = resolvedBase.warning {
            appendWarning(warning)
        }
        if options.accessLevel == .internal && options.includePackageManifest {
            appendWarning(
                "Internal access is selected. The generated Swift package cannot be imported from another module.",
                severity: .info
            )
        }

        registerComponentModels()
        buildOperations()
        discoverModelDependencies()
        detectRecursiveModels()
    }

    // MARK: - Setup

    private static func detectVersion(_ root: [String: SpecValue]) throws -> SpecVersion {
        if let openAPI = root["openapi"]?.stringValue, openAPI.hasPrefix("3") {
            return .openAPI3(openAPI)
        }
        if root["swagger"]?.stringValue == "2.0" {
            return .swagger2
        }
        throw GeneratorError.unsupportedSpecification
    }

    private static func findSchemas(root: [String: SpecValue], version: SpecVersion) -> [String: SpecValue] {
        switch version {
        case .openAPI3:
            return root["components"]?["schemas"]?.objectValue ?? [:]
        case .swagger2:
            return root["definitions"]?.objectValue ?? [:]
        }
    }

    private static func makePackageName(from title: String) -> String {
        var base = SwiftNaming.pascal(title)
        if base.isEmpty {
            base = "GeneratedAPI"
        }
        if base.count > 40 {
            base = String(base.prefix(40))
        }
        if base.lowercased().hasSuffix("kit") {
            return base
        }
        return base + "Kit"
    }

    private static func resolveBaseURL(
        root: [String: SpecValue],
        version: SpecVersion,
        options: GeneratorOptions
    ) -> (url: String, warning: String?) {
        let override = options.baseURLOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty {
            var candidate = override
            if !candidate.lowercased().hasPrefix("http://")
                && !candidate.lowercased().hasPrefix("https://") {
                candidate = "https://" + candidate
            }
            candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let components = URLComponents(string: candidate),
               let scheme = components.scheme?.lowercased(),
               (scheme == "http" || scheme == "https"),
               components.host != nil {
                return (candidate, nil)
            }
            return ("https://api.example.com", "The base URL override is invalid; https://api.example.com was used instead.")
        }

        switch version {
        case .openAPI3:
            if let server = root["servers"]?.arrayValue?.first?.objectValue,
               var url = server["url"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !url.isEmpty {
                if let variables = server["variables"]?.objectValue {
                    for (name, value) in variables {
                        let defaultValue = value["default"]?.stringValue ?? ""
                        url = url.replacingOccurrences(of: "{\(name)}", with: defaultValue)
                    }
                }
                if url.hasPrefix("/") {
                    url = "https://api.example.com" + url
                }
                if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
                    return ("https://api.example.com", "The server URL is relative; https://api.example.com was used instead.")
                }
                url = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let components = URLComponents(string: url),
                   let scheme = components.scheme?.lowercased(),
                   (scheme == "http" || scheme == "https"),
                   components.host != nil {
                    return (url, nil)
                }
            }
            return ("https://api.example.com", "No absolute server URL was found; https://api.example.com was used instead.")

        case .swagger2:
            let schemes = root["schemes"]?.stringArrayValue ?? []
            let scheme = schemes.first(where: { $0 == "https" || $0 == "http" }) ?? "https"
            let host = root["host"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let basePath = root["basePath"]?.stringValue?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            guard let host, !host.isEmpty else {
                return ("https://api.example.com", "No host was found in the Swagger document; https://api.example.com was used instead.")
            }
            var url = "\(scheme)://\(host)"
            if !basePath.isEmpty {
                url += "/\(basePath)"
            }
            return (url, nil)
        }
    }

    // MARK: - Warnings

    func appendWarning(_ message: String, context: String? = nil, severity: GenerationWarning.Severity = .warning) {
        let signature = "\(severity.rawValue)|\(context ?? "")|\(message)"
        guard warnedMessages.insert(signature).inserted else { return }
        warnings.append(GenerationWarning(message: message, context: context, severity: severity))
    }

    func appendInfo(_ message: String, context: String? = nil) {
        appendWarning(message, context: context, severity: .info)
    }

    var effectiveAccessPrefix: String {
        options.accessLevel.swiftPrefix
    }

    // MARK: - Reference resolution

    func resolvePointer(_ ref: String) -> SpecValue? {
        if ref == "#" { return raw }
        guard ref.hasPrefix("#/") else { return nil }
        let pointer = String(ref.dropFirst(2))
        var current = raw
        for token in pointer.split(separator: "/", omittingEmptySubsequences: false) {
            var key = String(token)
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            if let decoded = key.removingPercentEncoding {
                key = decoded
            }
            guard let object = current.objectValue, let next = object[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    func dereference(_ value: SpecValue, depth: Int = 0) -> SpecValue {
        guard depth < 16,
              let object = value.objectValue,
              let ref = object["$ref"]?.stringValue
        else {
            return value
        }

        guard let resolved = resolvePointer(ref) else {
            appendWarning(
                "An external or unresolved reference could not be followed: \(ref)",
                context: ref
            )
            return value
        }

        var siblings = object
        siblings.removeValue(forKey: "$ref")
        if siblings.isEmpty {
            return resolved
        }
        if let resolvedObject = resolved.objectValue {
            return .object(resolvedObject.merging(siblings) { _, sibling in sibling })
        }
        return resolved
    }

    // MARK: - Model registry

    private func registerComponentModels() {
        for key in schemas.keys.sorted() {
            guard let schema = schemas[key] else { continue }
            let refKey = specVersion.schemaRefPrefix + Self.escapeJSONPointer(key)
            let name = registerModel(schema: schema, hint: key, sourceKey: key, refKey: refKey)
            refToModelName[refKey] = name
        }
    }

    @discardableResult
    private func registerModel(
        schema: SpecValue,
        hint: String,
        sourceKey: String?,
        refKey: String? = nil
    ) -> String {
        let name = allocateTypeName(hint)
        let model = ModelDefinition(
            name: name,
            schema: schema,
            kind: classify(schema),
            sourceKey: sourceKey
        )
        models[name] = model
        modelOrder.append(name)
        if let refKey {
            refToModelName[refKey] = name
        }
        return name
    }

    private func allocateTypeName(_ rawHint: String) -> String {
        var base = SwiftNaming.pascal(rawHint)
        if base.isEmpty {
            base = "GeneratedModel"
        }
        let prefix = Self.sanitizedTypePrefix(options.typePrefix)
        if !prefix.isEmpty && !base.hasPrefix(prefix) {
            base = prefix + base
        }
        if Self.reservedTypeNames.contains(base) {
            base += "Model"
        }

        var candidate = base
        var suffix = 2
        while usedTypeNames.contains(candidate) {
            candidate = base + String(suffix)
            suffix += 1
        }
        usedTypeNames.insert(candidate)
        return candidate
    }

    private func allocateOperationName(_ rawHint: String, fallback: String) -> String {
        var base = SwiftNaming.camel(rawHint)
        if base.isEmpty {
            base = SwiftNaming.camel(fallback)
        }
        if base.isEmpty {
            base = "request"
        }
        if Self.reservedOperationNames.contains(base) {
            base += "Endpoint"
        }
        var candidate = base
        var suffix = 2
        while usedOperationNames.contains(candidate) {
            candidate = base + String(suffix)
            suffix += 1
        }
        usedOperationNames.insert(candidate)
        return candidate
    }

    private func classify(_ schema: SpecValue) -> ModelDefinition.Kind {
        guard let object = schema.objectValue else { return .alias }

        if object["oneOf"]?.arrayValue?.isEmpty == false
            || object["anyOf"]?.arrayValue?.isEmpty == false {
            return .union
        }

        if let values = object["enum"]?.arrayValue, !values.isEmpty {
            let values = values.filter { !$0.isNull }
            if !values.isEmpty, values.allSatisfy({ $0.stringValue != nil }) {
                return .stringEnum
            }
            if !values.isEmpty, values.allSatisfy({ $0.int64Value != nil }) {
                return .intEnum
            }
            return .alias
        }

        if object["allOf"]?.arrayValue?.isEmpty == false {
            let merged = mergedObjectSchema(schema)
            if merged["properties"]?.objectValue?.isEmpty == false {
                return .object
            }
            return .alias
        }

        if object["properties"]?.objectValue?.isEmpty == false {
            return .object
        }

        return .alias
    }

    private func ensureModel(schema: SpecValue, hint: String, sourceKey: String? = nil) -> String {
        if let ref = schema["$ref"]?.stringValue, let existing = refToModelName[ref] {
            return existing
        }
        return registerModel(schema: schema, hint: hint, sourceKey: sourceKey)
    }

    // MARK: - Schema helpers

    func schemaTypes(_ schema: [String: SpecValue]) -> [String] {
        if let value = schema["type"]?.stringValue {
            return [value]
        }
        return schema["type"]?.stringArrayValue ?? []
    }

    func isNullable(_ schema: SpecValue, object: [String: SpecValue]? = nil) -> Bool {
        let object = object ?? schema.objectValue ?? [:]
        if object["nullable"]?.boolValue == true {
            return true
        }
        if schemaTypes(object).contains("null") {
            return true
        }
        if let variations = object["oneOf"]?.arrayValue ?? object["anyOf"]?.arrayValue {
            return variations.contains(where: { value in
                value.objectValue.map { schemaTypes($0).contains("null") } ?? false
            })
        }
        return false
    }

    func mergedObjectSchema(_ schema: SpecValue, depth: Int = 0) -> [String: SpecValue] {
        guard depth < 16, var object = schema.objectValue else { return [:] }

        if let ref = object["$ref"]?.stringValue,
           let resolved = resolvePointer(ref)?.objectValue {
            var merged = mergedObjectSchema(.object(resolved), depth: depth + 1)
            object.removeValue(forKey: "$ref")
            merged.merge(object) { _, own in own }
            return merged
        }

        var properties: [String: SpecValue] = [:]
        var required: Set<String> = []

        if let allOf = object["allOf"]?.arrayValue {
            for member in allOf {
                let resolved = dereference(member, depth: depth + 1)
                let merged = mergedObjectSchema(resolved, depth: depth + 1)
                if let memberProperties = merged["properties"]?.objectValue {
                    properties.merge(memberProperties) { _, new in new }
                }
                if let memberRequired = merged["required"]?.stringArrayValue {
                    required.formUnion(memberRequired)
                }
            }
        }

        if let ownProperties = object["properties"]?.objectValue {
            properties.merge(ownProperties) { _, own in own }
        }
        if let ownRequired = object["required"]?.stringArrayValue {
            required.formUnion(ownRequired)
        }

        var merged = object
        merged.removeValue(forKey: "allOf")
        merged["type"] = .string("object")
        if properties.isEmpty {
            merged.removeValue(forKey: "properties")
        } else {
            merged["properties"] = .object(properties)
        }
        if required.isEmpty {
            merged.removeValue(forKey: "required")
        } else {
            merged["required"] = .array(required.sorted().map(SpecValue.string))
        }
        return merged
    }

    private func unionVariations(_ object: [String: SpecValue]) -> [SpecValue] {
        (object["oneOf"]?.arrayValue ?? object["anyOf"]?.arrayValue ?? [])
            .filter { variation in
                guard let object = variation.objectValue else { return true }
                return !schemaTypes(object).contains("null") && object["type"]?.stringValue != "null"
            }
    }

    // MARK: - Type resolution

    func resolveType(_ schema: SpecValue, hint: String, key: String) -> ResolvedType {
        if let cached = typeCache[key] {
            return cached
        }
        guard !typesInProgress.contains(key) else {
            return ResolvedType(swiftType: "JSONValue", scalar: .json)
        }

        typesInProgress.insert(key)
        let result = computeType(schema, hint: hint, key: key)
        typesInProgress.remove(key)
        typeCache[key] = result
        return result
    }

    private func computeType(_ rawSchema: SpecValue, hint: String, key: String) -> ResolvedType {
        guard let object = rawSchema.objectValue else {
            return jsonValueType()
        }

        let nullable = isNullable(rawSchema, object: object)

        if let ref = object["$ref"]?.stringValue {
            if let name = refToModelName[ref] {
                var type = modelType(name)
                type.nullable = type.nullable || nullable
                return type
            }
            if let resolved = resolvePointer(ref) {
                var type = resolveType(resolved, hint: hint, key: key + ".resolved")
                type.nullable = type.nullable || nullable
                return type
            }
            appendWarning("Unresolved reference mapped to JSONValue: \(ref)", context: ref)
            return jsonValueType(nullable: nullable)
        }

        if object["allOf"]?.arrayValue?.isEmpty == false {
            let merged = mergedObjectSchema(rawSchema)
            if merged["properties"]?.objectValue?.isEmpty == false {
                let name = ensureModel(schema: .object(merged), hint: hint)
                return compositeType(name: name, nullable: nullable)
            }
            var type = resolveType(.object(merged), hint: hint, key: key + ".allOf")
            type.nullable = type.nullable || nullable
            return type
        }

        if object["oneOf"]?.arrayValue?.isEmpty == false
            || object["anyOf"]?.arrayValue?.isEmpty == false {
            let name = ensureModel(schema: rawSchema, hint: hint)
            return compositeType(name: name, nullable: nullable)
        }

        if let enumValues = object["enum"]?.arrayValue, !enumValues.isEmpty {
            let values = enumValues.filter { !$0.isNull }
            if !values.isEmpty, values.allSatisfy({ $0.stringValue != nil }) {
                let name = ensureModel(schema: rawSchema, hint: hint)
                var type = modelType(name)
                type.nullable = type.nullable || nullable
                return type
            }
            if !values.isEmpty, values.allSatisfy({ $0.int64Value != nil }) {
                let name = ensureModel(schema: rawSchema, hint: hint)
                var type = modelType(name)
                type.nullable = type.nullable || nullable
                return type
            }
            appendWarning(
                "An enum with mixed or unsupported values was mapped to JSONValue.",
                context: key
            )
            return jsonValueType(nullable: nullable)
        }

        var types = schemaTypes(object)
        if types.contains("null") {
            types.removeAll { $0 == "null" }
        }
        if types.count > 1 {
            appendWarning(
                "A property with multiple types was mapped to JSONValue.",
                context: key
            )
            return jsonValueType(nullable: nullable)
        }

        let type = types.first
        if type == "array" {
            let itemSchema = object["items"] ?? .object(["type": .string("string")])
            let item = resolveType(itemSchema, hint: hint + "Item", key: key + ".item")
            let elementType = item.swiftType + (item.nullable ? "?" : "")
            return ResolvedType(
                swiftType: "[\(elementType)]",
                nullable: nullable,
                scalar: nil,
                arrayElementType: item.swiftType + (item.nullable ? "?" : ""),
                arrayElementScalar: item.scalar,
                dependencies: item.dependencies
            )
        }

        if type == "object" || object["properties"] != nil {
            if object["properties"]?.objectValue?.isEmpty == false {
                let name = ensureModel(schema: rawSchema, hint: hint)
                return compositeType(name: name, nullable: nullable)
            }
            if let additional = object["additionalProperties"], additional.boolValue != false {
                return additionalPropertiesType(additional, hint: hint, key: key, nullable: nullable)
            }
            appendInfo("A free-form object was mapped to JSONValue.", context: key)
            return jsonValueType(nullable: nullable)
        }

        if let additional = object["additionalProperties"], additional.boolValue != false {
            return additionalPropertiesType(additional, hint: hint, key: key, nullable: nullable)
        }

        switch type {
        case "string":
            let format = object["format"]?.stringValue
            switch format {
            case "date-time", "date":
                if options.dateMapping == .date {
                    return ResolvedType(swiftType: "Date", nullable: nullable, scalar: .date)
                }
                return ResolvedType(swiftType: "String", nullable: nullable, scalar: .string)
            case "binary":
                appendWarning("Binary strings are represented as Data.", context: key)
                return ResolvedType(swiftType: "Data", nullable: nullable, scalar: .data)
            default:
                return ResolvedType(swiftType: "String", nullable: nullable, scalar: .string)
            }

        case "integer":
            let format = object["format"]?.stringValue
            if format == "int64" {
                return ResolvedType(swiftType: "Int64", nullable: nullable, scalar: .number)
            }
            return ResolvedType(swiftType: "Int", nullable: nullable, scalar: .number)

        case "number":
            if object["format"]?.stringValue == "float" {
                return ResolvedType(swiftType: "Float", nullable: nullable, scalar: .number)
            }
            return ResolvedType(swiftType: "Double", nullable: nullable, scalar: .number)

        case "boolean":
            return ResolvedType(swiftType: "Bool", nullable: nullable, scalar: .boolean)

        case "null":
            return jsonValueType(nullable: true)

        case "file":
            appendWarning("File upload fields are represented as Data.", context: key)
            return ResolvedType(swiftType: "Data", nullable: nullable, scalar: .data)

        default:
            break
        }

        if let constant = object["const"] {
            switch constant {
            case .string:
                return ResolvedType(swiftType: "String", nullable: nullable, scalar: .string)
            case .integer:
                return ResolvedType(swiftType: "Int", nullable: nullable, scalar: .number)
            case .number:
                return ResolvedType(swiftType: "Double", nullable: nullable, scalar: .number)
            case .bool:
                return ResolvedType(swiftType: "Bool", nullable: nullable, scalar: .boolean)
            default:
                break
            }
        }

        appendInfo("An unconstrained schema was mapped to JSONValue.", context: key)
        return jsonValueType(nullable: nullable)
    }

    private func additionalPropertiesType(
        _ additional: SpecValue,
        hint: String,
        key: String,
        nullable: Bool
    ) -> ResolvedType {
        if additional.objectValue == nil {
            return jsonValueType(nullable: nullable)
        }
        let value = resolveType(additional, hint: hint + "Value", key: key + ".value")
        let valueType = value.swiftType + (value.nullable ? "?" : "")
        return ResolvedType(
            swiftType: "[String: \(valueType)]",
            nullable: nullable,
            dependencies: value.dependencies
        )
    }

    private func compositeType(name: String, nullable: Bool) -> ResolvedType {
        var type = modelType(name)
        type.nullable = type.nullable || nullable
        type.dependencies.insert(name)
        return type
    }

    func modelType(_ name: String) -> ResolvedType {
        guard let model = models[name] else {
            return jsonValueType()
        }
        switch model.kind {
        case .stringEnum:
            return ResolvedType(swiftType: name, scalar: .enumString, dependencies: [name])
        case .intEnum:
            return ResolvedType(swiftType: name, scalar: .enumInt, dependencies: [name])
        case .object:
            return ResolvedType(swiftType: name, scalar: .object, dependencies: [name])
        case .union:
            return ResolvedType(swiftType: name, scalar: .object, dependencies: [name])
        case .alias:
            return ResolvedType(swiftType: name, scalar: nil, dependencies: [name])
        }
    }

    func jsonValueType(nullable: Bool = false) -> ResolvedType {
        usesJSONValue = true
        return ResolvedType(swiftType: "JSONValue", nullable: nullable, scalar: .json)
    }

    // MARK: - Object properties

    func objectProperties(for modelName: String) -> [ObjectProperty] {
        if let cached = objectPropertiesCache[modelName] {
            return cached
        }
        guard let model = models[modelName] else { return [] }

        let schema = mergedObjectSchema(model.schema)
        if let rawProperties = schema["properties"]?.objectValue, !rawProperties.isEmpty {
            if let additional = schema["additionalProperties"], additional.boolValue != false {
                appendWarning(
                    "Additional properties are ignored because the schema also declares fixed properties.",
                    context: modelName
                )
            }
        } else if schema["additionalProperties"]?.boolValue == true {
            appendInfo("A free-form object was mapped to JSONValue.", context: modelName)
        }

        let required = Set(schema["required"]?.stringArrayValue ?? [])
        let rawProperties = schema["properties"]?.objectValue ?? [:]
        var usedNames: Set<String> = []
        var properties: [ObjectProperty] = []

        for key in rawProperties.keys.sorted() {
            guard let rawProperty = rawProperties[key] else { continue }
            let propertyObject = rawProperty.objectValue ?? [:]
            let hint = modelName + SwiftNaming.pascal(key)
            let type = resolveType(
                rawProperty,
                hint: hint,
                key: modelName + ".property." + key
            )
            var swiftName = SwiftNaming.property(key)
            if usedNames.contains(swiftName) {
                let base = SwiftNaming.camel(key)
                var suffix = 2
                while usedNames.contains(SwiftNaming.escape(base + String(suffix))) {
                    suffix += 1
                }
                swiftName = SwiftNaming.escape(base + String(suffix))
            }
            usedNames.insert(swiftName)
            let isOptional = !required.contains(key) || type.nullable
            properties.append(ObjectProperty(
                jsonKey: key,
                swiftName: swiftName,
                type: type,
                isOptional: isOptional,
                description: propertyObject["description"]?.stringValue,
                isDeprecated: propertyObject["deprecated"]?.boolValue == true
            ))
        }

        objectPropertiesCache[modelName] = properties
        return properties
    }

    func unionTypes(for modelName: String) -> [ResolvedType] {
        guard let model = models[modelName], let object = model.schema.objectValue else {
            return []
        }
        return unionVariations(object).enumerated().map { index, variation in
            resolveType(
                variation,
                hint: modelName + "Variant\(index + 1)",
                key: modelName + ".variant.\(index)"
            )
        }
    }

    func enumValues(for modelName: String) -> [SpecValue] {
        guard let model = models[modelName],
              let values = model.schema["enum"]?.arrayValue
        else {
            return []
        }
        return values.filter { !$0.isNull }
    }

    // MARK: - Operations

    private func buildOperations() {
        guard let paths = root["paths"]?.objectValue, !paths.isEmpty else {
            appendWarning("The specification does not define any paths.")
            return
        }

        for path in paths.keys.sorted() {
            guard let rawPathItem = paths[path] else { continue }
            let pathItem = dereference(rawPathItem).objectValue ?? [:]
            let commonParameters = pathItem["parameters"]?.arrayValue ?? []

            for method in Self.httpMethods {
                guard let operation = pathItem[method]?.objectValue
                    ?? pathItem[method.uppercased()]?.objectValue
                else {
                    continue
                }

                let operationID = operation["operationId"]?.stringValue ?? ""
                let fallback = Self.fallbackOperationName(method: method, path: path)
                let swiftName = allocateOperationName(operationID, fallback: fallback)
                let operationParameters = mergeParameters(
                    common: commonParameters,
                    operation: operation["parameters"]?.arrayValue ?? []
                )

                do {
                    let definition = try buildOperation(
                        method: method,
                        path: path,
                        operation: operation,
                        swiftName: swiftName,
                        rawParameters: operationParameters
                    )
                    operations.append(definition)
                } catch {
                    appendWarning(
                        "Skipped \(method.uppercased()) \(path): \(error.localizedDescription)",
                        context: "\(method) \(path)"
                    )
                }
            }
        }

        operations.sort {
            if $0.path == $1.path { return $0.method < $1.method }
            return $0.path < $1.path
        }
    }

    private static func fallbackOperationName(method: String, path: String) -> String {
        var pieces = [method]
        for segment in path.split(separator: "/", omittingEmptySubsequences: true) {
            let text = String(segment)
            if text.hasPrefix("{"), text.hasSuffix("}") {
                pieces.append("by")
                pieces.append(String(text.dropFirst().dropLast()))
            } else {
                pieces.append(text)
            }
        }
        return pieces.joined(separator: " ")
    }

    private func mergeParameters(common: [SpecValue], operation: [SpecValue]) -> [SpecValue] {
        var ordered: [SpecValue] = []
        var indexByKey: [String: Int] = [:]

        func key(for parameter: SpecValue) -> String? {
            let resolved = dereference(parameter).objectValue ?? [:]
            guard let name = resolved["name"]?.stringValue,
                  let location = resolved["in"]?.stringValue
            else {
                return nil
            }
            return "\(location):\(name)"
        }

        for parameter in common {
            guard let key = key(for: parameter) else {
                ordered.append(parameter)
                continue
            }
            indexByKey[key] = ordered.count
            ordered.append(parameter)
        }
        for parameter in operation {
            guard let key = key(for: parameter) else {
                ordered.append(parameter)
                continue
            }
            if let index = indexByKey[key] {
                ordered[index] = parameter
            } else {
                indexByKey[key] = ordered.count
                ordered.append(parameter)
            }
        }
        return ordered
    }

    private func buildOperation(
        method: String,
        path: String,
        operation: [String: SpecValue],
        swiftName: String,
        rawParameters: [SpecValue]
    ) throws -> OperationDefinition {
        var usedNames: Set<String> = []
        var parameters: [OperationParameter] = []
        var bodyParameter: [String: SpecValue]?
        var hasFormData = false

        for rawParameter in rawParameters {
            let parameter = dereference(rawParameter).objectValue ?? [:]
            guard let location = parameter["in"]?.stringValue,
                  let name = parameter["name"]?.stringValue,
                  !name.isEmpty
            else {
                continue
            }

            if location == "body" {
                bodyParameter = parameter
                continue
            }
            if location == "formData" {
                hasFormData = true
                continue
            }
            if location == "cookie" {
                appendWarning(
                    "Cookie parameters are not supported and were skipped.",
                    context: "\(method.uppercased()) \(path)"
                )
                continue
            }
            guard location == "path" || location == "query" || location == "header" else {
                continue
            }
            if location == "header",
               ["authorization", "content-type", "accept"].contains(name.lowercased()) {
                continue
            }

            let schema = parameterSchema(parameter)
            let type = resolveType(
                schema,
                hint: SwiftNaming.pascal(swiftName) + SwiftNaming.pascal(name),
                key: "\(swiftName).parameter.\(location).\(name)"
            )
            let required = location == "path" || parameter["required"]?.boolValue == true
            let explode = parameterExplode(parameter, location: location)
            let swiftParameterName = uniqueParameterName(name, used: &usedNames)

            parameters.append(OperationParameter(
                location: OperationParameter.Location(rawValue: location)!,
                jsonName: name,
                swiftName: swiftParameterName,
                type: type,
                isRequired: required,
                description: parameter["description"]?.stringValue,
                explode: explode
            ))
        }

        // Ensure every templated path segment has a value.
        let pathNames = Set(parameters.filter { $0.location == .path }.map(\.jsonName))
        for placeholder in Self.pathPlaceholders(in: path) where !pathNames.contains(placeholder) {
            let swiftParameterName = uniqueParameterName(placeholder, used: &usedNames)
            parameters.append(OperationParameter(
                location: .path,
                jsonName: placeholder,
                swiftName: swiftParameterName,
                type: ResolvedType(swiftType: "String", scalar: .string),
                isRequired: true,
                description: nil,
                explode: false
            ))
            appendWarning(
                "The path parameter “\(placeholder)” is not declared; a String argument was added.",
                context: "\(method.uppercased()) \(path)"
            )
        }

        // Keep path parameters first, then query parameters, then headers.
        parameters.sort { lhs, rhs in
            let order: [OperationParameter.Location: Int] = [.path: 0, .query: 1, .header: 2]
            return (order[lhs.location] ?? 9) < (order[rhs.location] ?? 9)
        }

        var body: OperationBody?
        if let requestBody = try buildRequestBody(
            operation: operation,
            path: path,
            method: method,
            swiftName: swiftName,
            bodyParameter: bodyParameter,
            hasFormData: hasFormData,
            usedNames: &usedNames
        ) {
            body = requestBody
        }

        let response = buildResponse(
            operation: operation,
            path: path,
            method: method,
            swiftName: swiftName
        )

        let summary = operation["summary"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "\(method.uppercased()) \(path)"
        let tag = operation["tags"]?.stringArrayValue?.first

        return OperationDefinition(
            method: method.uppercased(),
            path: path.hasPrefix("/") ? path : "/" + path,
            swiftName: swiftName,
            summary: summary,
            description: operation["description"]?.stringValue,
            tag: tag,
            isDeprecated: operation["deprecated"]?.boolValue == true,
            parameters: parameters,
            body: body,
            response: response
        )
    }

    private func parameterSchema(_ parameter: [String: SpecValue]) -> SpecValue {
        if let schema = parameter["schema"] {
            return schema
        }
        if let content = parameter["content"]?.objectValue, !content.isEmpty {
            let media = preferredMediaType(in: content)
            if let media, let schema = content[media]?["schema"] {
                return schema
            }
        }

        var schema: [String: SpecValue] = [:]
        for key in ["type", "format", "items", "enum", "default", "minimum", "maximum", "nullable"] {
            if let value = parameter[key] {
                schema[key] = value
            }
        }
        if schema.isEmpty {
            schema["type"] = .string("string")
        }
        return .object(schema)
    }

    private func parameterExplode(_ parameter: [String: SpecValue], location: String) -> Bool {
        if let explode = parameter["explode"]?.boolValue {
            return explode
        }
        if let format = parameter["collectionFormat"]?.stringValue {
            switch format {
            case "multi": return true
            case "csv", "ssv", "tsv", "pipes": return false
            default: break
            }
        }
        return location == "query"
    }

    private func buildRequestBody(
        operation: [String: SpecValue],
        path: String,
        method: String,
        swiftName: String,
        bodyParameter: [String: SpecValue]?,
        hasFormData: Bool,
        usedNames: inout Set<String>
    ) throws -> OperationBody? {
        var schema: SpecValue?
        var contentType = "application/json"
        var required = true

        if let requestBody = operation["requestBody"] {
            let resolved = dereference(requestBody).objectValue ?? [:]
            required = resolved["required"]?.boolValue == true
            if let content = resolved["content"]?.objectValue, !content.isEmpty {
                guard let media = preferredJSONMediaType(in: content),
                      let mediaObject = content[media],
                      let mediaSchema = mediaObject["schema"]
                else {
                    appendWarning(
                        "Only JSON request bodies are supported. The body was skipped.",
                        context: "\(method.uppercased()) \(path)"
                    )
                    return nil
                }
                contentType = media
                schema = mediaSchema
            } else {
                schema = resolved["schema"]
            }
        } else if let bodyParameter {
            schema = bodyParameter["schema"]
            required = bodyParameter["required"]?.boolValue == true
            if let consumes = operation["consumes"]?.stringArrayValue ?? root["consumes"]?.stringArrayValue,
               let media = consumes.first(where: { $0.lowercased().contains("json") }) {
                contentType = media
            }
        } else if hasFormData {
            appendWarning(
                "multipart and form-encoded bodies are not supported; form fields were skipped.",
                context: "\(method.uppercased()) \(path)"
            )
            return nil
        }

        guard let schema else { return nil }
        let type = resolveType(
            schema,
            hint: SwiftNaming.pascal(swiftName) + "Request",
            key: swiftName + ".request"
        )
        let bodyName = uniqueParameterName("body", used: &usedNames)
        return OperationBody(
            swiftName: bodyName,
            type: type,
            isRequired: required,
            contentType: contentType
        )
    }

    private func buildResponse(
        operation: [String: SpecValue],
        path: String,
        method: String,
        swiftName: String
    ) -> OperationResponse {
        guard let responses = operation["responses"]?.objectValue, !responses.isEmpty else {
            return OperationResponse(kind: .empty)
        }

        let status = preferredResponseStatus(in: responses)
        guard let status, let rawResponse = responses[status] else {
            return OperationResponse(kind: .empty)
        }
        if status == "default" {
            appendInfo(
                "No explicit success response was found; the default response was used.",
                context: "\(method.uppercased()) \(path)"
            )
        }

        let response = dereference(rawResponse).objectValue ?? [:]
        if status == "204" {
            return OperationResponse(kind: .empty)
        }

        if let content = response["content"]?.objectValue, !content.isEmpty {
            guard let media = preferredResponseMediaType(in: content),
                  let mediaObject = content[media]
            else {
                return OperationResponse(kind: .empty)
            }
            let mediaType = media.lowercased()
            if isTextMediaType(mediaType) {
                return OperationResponse(kind: .text, mediaType: media)
            }
            if isBinaryMediaType(mediaType) {
                return OperationResponse(kind: .data, mediaType: media)
            }
            guard let schema = mediaObject["schema"] else {
                return OperationResponse(kind: .json, type: jsonValueType(), mediaType: media)
            }
            let type = resolveType(
                schema,
                hint: SwiftNaming.pascal(swiftName) + "Response",
                key: swiftName + ".response"
            )
            return OperationResponse(kind: .json, type: type, mediaType: media)
        }

        if let schema = response["schema"] {
            let produces = operation["produces"]?.stringArrayValue ?? root["produces"]?.stringArrayValue ?? []
            let media = produces.first(where: { $0.lowercased().contains("json") })
                ?? produces.first
                ?? "application/json"
            let mediaType = media.lowercased()
            if isTextMediaType(mediaType) {
                return OperationResponse(kind: .text, mediaType: media)
            }
            if isBinaryMediaType(mediaType) {
                return OperationResponse(kind: .data, mediaType: media)
            }
            let type = resolveType(
                schema,
                hint: SwiftNaming.pascal(swiftName) + "Response",
                key: swiftName + ".response"
            )
            return OperationResponse(kind: .json, type: type, mediaType: media)
        }

        return OperationResponse(kind: .empty)
    }

    private func preferredResponseStatus(in responses: [String: SpecValue]) -> String? {
        let preferred = ["200", "201", "202", "203", "204", "205", "206", "207", "208", "226"]
        if let status = preferred.first(where: { responses[$0] != nil }) {
            return status
        }
        if let status = responses.keys
            .filter({ $0.lowercased().hasPrefix("2") })
            .sorted()
            .first {
            return status
        }
        if responses["default"] != nil {
            return "default"
        }
        return responses.keys.sorted().first
    }

    private func preferredJSONMediaType(in content: [String: SpecValue]) -> String? {
        let keys = content.keys.sorted()
        if let exact = keys.first(where: { $0.lowercased() == "application/json" }) {
            return exact
        }
        if let json = keys.first(where: { $0.lowercased().contains("json") }) {
            return json
        }
        return nil
    }

    private func preferredMediaType(in content: [String: SpecValue]) -> String? {
        preferredJSONMediaType(in: content) ?? content.keys.sorted().first
    }

    private func preferredResponseMediaType(in content: [String: SpecValue]) -> String? {
        if let json = preferredJSONMediaType(in: content) {
            return json
        }
        let keys = content.keys.sorted()
        if let text = keys.first(where: { $0.lowercased().hasPrefix("text/") }) {
            return text
        }
        if let binary = keys.first(where: { isBinaryMediaType($0.lowercased()) }) {
            return binary
        }
        return keys.first
    }

    private func isTextMediaType(_ mediaType: String) -> Bool {
        mediaType.hasPrefix("text/") || mediaType.contains("xml") || mediaType.contains("html")
    }

    private func isBinaryMediaType(_ mediaType: String) -> Bool {
        mediaType.contains("octet-stream")
            || mediaType.contains("application/pdf")
            || mediaType.contains("image/")
            || mediaType.contains("audio/")
            || mediaType.contains("video/")
    }

    private func uniqueParameterName(_ raw: String, used: inout Set<String>) -> String {
        var base = SwiftNaming.camel(raw)
        if base.isEmpty {
            base = "value"
        }
        var candidate = SwiftNaming.escape(base)
        var suffix = 2
        while used.contains(candidate) {
            candidate = SwiftNaming.escape(base + String(suffix))
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    static func pathPlaceholders(in path: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inPlaceholder = false
        for character in path {
            if character == "{" {
                inPlaceholder = true
                current = ""
            } else if character == "}" && inPlaceholder {
                if !current.isEmpty {
                    result.append(current)
                }
                inPlaceholder = false
            } else if inPlaceholder {
                current.append(character)
            }
        }
        return result
    }

    // MARK: - Dependency discovery and cycles

    private func discoverModelDependencies() {
        var index = 0
        while index < modelOrder.count {
            let name = modelOrder[index]
            index += 1
            guard var model = models[name] else { continue }
            model.dependencies = dependencies(for: model)
            models[name] = model
        }
    }

    private func dependencies(for model: ModelDefinition) -> Set<String> {
        switch model.kind {
        case .stringEnum, .intEnum:
            return []
        case .object:
            var dependencies: Set<String> = []
            for property in objectProperties(for: model.name) {
                dependencies.formUnion(property.type.dependencies)
            }
            return dependencies
        case .union:
            var dependencies: Set<String> = []
            for type in unionTypes(for: model.name) {
                dependencies.formUnion(type.dependencies)
            }
            return dependencies
        case .alias:
            let type = resolveType(
                model.schema,
                hint: model.name,
                key: model.name + ".alias"
            )
            return type.dependencies
        }
    }

    private func detectRecursiveModels() {
        var nextIndex = 0
        var stack: [String] = []
        var onStack: Set<String> = []
        var indices: [String: Int] = [:]
        var lowLinks: [String: Int] = [:]
        var components: [[String]] = []

        func strongConnect(_ node: String) {
            indices[node] = nextIndex
            lowLinks[node] = nextIndex
            nextIndex += 1
            stack.append(node)
            onStack.insert(node)

            let dependencies = models[node]?.dependencies ?? []
            for dependency in dependencies.sorted() where models[dependency] != nil {
                if indices[dependency] == nil {
                    strongConnect(dependency)
                    lowLinks[node] = min(lowLinks[node] ?? 0, lowLinks[dependency] ?? 0)
                } else if onStack.contains(dependency) {
                    lowLinks[node] = min(lowLinks[node] ?? 0, indices[dependency] ?? 0)
                }
            }

            if lowLinks[node] == indices[node] {
                var component: [String] = []
                while let last = stack.popLast() {
                    onStack.remove(last)
                    component.append(last)
                    if last == node { break }
                }
                components.append(component)
            }
        }

        for name in modelOrder where indices[name] == nil {
            strongConnect(name)
        }

        for component in components {
            let isSelfCycle = component.count == 1
                && (models[component[0]]?.dependencies.contains(component[0]) ?? false)
            guard component.count > 1 || isSelfCycle else { continue }
            for name in component {
                models[name]?.isRecursive = true
                if models[name]?.kind == .alias {
                    appendWarning(
                        "A recursive type alias cannot be represented; JSONValue will be used.",
                        context: name
                    )
                }
            }
        }
    }

    // MARK: - Utilities

    private static func escapeJSONPointer(_ value: String) -> String {
        value.replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
    }

    private static func sanitizedTypePrefix(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let words = SwiftNaming.words(in: trimmed)
        if words.count == 1, let word = words.first,
           word.count > 1, word.allSatisfy({ $0.isUppercase || $0.isNumber }) {
            return word
        }
        return SwiftNaming.pascal(trimmed)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
