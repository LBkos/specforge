import Foundation

enum SwiftGenerator {
    static func generate(
        parsed: ParsedSpecification,
        options: GeneratorOptions,
        sourceLabel: String
    ) throws -> GenerationResult {
        let context = try GeneratorContext(
            parsed: parsed,
            options: options,
            sourceLabel: sourceLabel
        )
        return context.makeResult()
    }

    static func generate(
        specification: String,
        options: GeneratorOptions,
        sourceLabel: String
    ) throws -> GenerationResult {
        let parsed = try SpecParser.parse(specification)
        return try generate(parsed: parsed, options: options, sourceLabel: sourceLabel)
    }
}
