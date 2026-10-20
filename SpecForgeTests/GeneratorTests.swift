import XCTest
@testable import SpecForge

final class GeneratorTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var exampleURL: URL {
        repositoryRoot
            .appendingPathComponent("SpecForge")
            .appendingPathComponent("Resources")
            .appendingPathComponent("ExampleSpec.json")
    }

    private var swaggerURL: URL {
        repositoryRoot
            .appendingPathComponent("SpecForgeTests")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("swagger2.yaml")
    }

    func testOpenAPIExampleGeneratesModelsAndEndpoints() throws {
        let specification = try String(contentsOf: exampleURL, encoding: .utf8)
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: GeneratorOptions(accessLevel: .public),
            sourceLabel: "ExampleSpec.json"
        )

        XCTAssertEqual(result.metadata.title, "Orbit Tasks API")
        XCTAssertEqual(result.metadata.version, "1.4.0")
        XCTAssertEqual(result.metadata.baseURL, "https://api.orbit.example/v1")
        XCTAssertEqual(result.endpointCount, 13)
        XCTAssertGreaterThanOrEqual(result.modelCount, 12)
        XCTAssertTrue(result.files.contains { $0.name == "Package.swift" })
        XCTAssertTrue(result.files.contains { $0.name == "JSONValue.swift" })
        XCTAssertEqual(result.packageName, "OrbitTasksAPIKit")

        let models = try XCTUnwrap(result.files.first { $0.name == "Models.swift" }?.content)
        XCTAssertTrue(models.contains("public struct Task: Codable"))
        XCTAssertTrue(models.contains("public final class Comment: Codable"))
        XCTAssertTrue(models.contains("public enum TaskStatus: String, Codable, CaseIterable"))
        XCTAssertTrue(models.contains("case inProgress = \"in_progress\""))
        XCTAssertTrue(models.contains("public enum Priority: Int, Codable, CaseIterable"))
        XCTAssertTrue(models.contains("public struct TaskDetail: Codable"))
        XCTAssertTrue(models.contains("public var latestComment: Comment"))
        XCTAssertTrue(models.contains("public enum Activity: Codable"))
        XCTAssertTrue(models.contains("case task(Task)"))
        XCTAssertTrue(models.contains("case comment(Comment)"))
        XCTAssertTrue(models.contains("case unknown(JSONValue)"))
        XCTAssertTrue(models.contains("struct AddCommentRequest: Codable"))
        XCTAssertTrue(models.contains("private enum CodingKeys: String, CodingKey"))
        XCTAssertTrue(models.contains("case externalID = \"external_id\""))
        XCTAssertTrue(models.contains("public var externalID: String?"))
        XCTAssertTrue(models.contains("public typealias TaskStatus") == false)

        let endpoints = try XCTUnwrap(result.files.first { $0.name == "Endpoints.swift" }?.content)
        XCTAssertTrue(endpoints.contains("public func listTasks("))
        XCTAssertTrue(endpoints.contains("status: TaskStatus? = nil"))
        XCTAssertTrue(endpoints.contains("tags: [String]? = nil"))
        XCTAssertTrue(endpoints.contains("queryItems.append(contentsOf: tags.map"))
        XCTAssertTrue(endpoints.contains("return try await send("))
        XCTAssertTrue(endpoints.contains("public func deleteTask(taskID: String) async throws -> Void"))
        XCTAssertTrue(endpoints.contains("try await sendEmpty("))
        XCTAssertTrue(endpoints.contains("public func healthCheck() async throws -> String"))
        XCTAssertTrue(endpoints.contains("return String(decoding: data, as: UTF8.self)"))
        XCTAssertTrue(endpoints.contains("public func downloadAttachment(taskID: String) async throws -> Data"))
        XCTAssertTrue(endpoints.contains("public func addComment(taskID: String, body: AddCommentRequest)"))
        XCTAssertFalse(endpoints.contains("\\{"))
    }

    func testSwaggerTwoYAML() throws {
        let specification = try String(contentsOf: swaggerURL, encoding: .utf8)
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: GeneratorOptions(accessLevel: .public),
            sourceLabel: "swagger2.yaml"
        )

        XCTAssertEqual(result.metadata.title, "Tiny Pets API")
        XCTAssertEqual(result.metadata.baseURL, "https://api.example.com/v2")
        XCTAssertEqual(result.endpointCount, 3)

        let models = try XCTUnwrap(result.files.first { $0.name == "Models.swift" }?.content)
        XCTAssertTrue(models.contains("public struct Pet: Codable"))
        XCTAssertTrue(models.contains("public var id: Int64"))
        XCTAssertTrue(models.contains("public struct Owner: Codable"))

        let endpoints = try XCTUnwrap(result.files.first { $0.name == "Endpoints.swift" }?.content)
        XCTAssertTrue(endpoints.contains("public func listPets(limit: Int? = nil) async throws -> [Pet]"))
        XCTAssertTrue(endpoints.contains("public func createPet(body: Pet) async throws -> Pet"))
        XCTAssertTrue(endpoints.contains("public func getPet(petID: String) async throws -> Pet"))
    }

    func testUnsupportedInputProducesReadableError() {
        XCTAssertThrowsError(try SwiftGenerator.generate(
            specification: "{\"hello\": \"world\"}",
            options: GeneratorOptions(),
            sourceLabel: "inline"
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("OpenAPI"))
        }
    }

    func testGeneratedSwiftCompiles() throws {
        let specification = try String(contentsOf: exampleURL, encoding: .utf8)
        var options = GeneratorOptions(accessLevel: .public)
        options.dateMapping = .date
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: options,
            sourceLabel: "ExampleSpec.json"
        )

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpecForgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        var swiftFiles: [String] = []
        for file in result.files where file.kind == .swift {
            let destination = temporary.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.content.write(to: destination, atomically: true, encoding: .utf8)
            swiftFiles.append(destination.path)
        }
        XCTAssertGreaterThanOrEqual(swiftFiles.count, 4)

        let output = temporary.appendingPathComponent("GeneratedAPI.swiftmodule")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swiftc",
            "-swift-version", "5",
            "-parse-as-library",
            "-emit-module",
            "-module-name", "GeneratedAPI",
            "-o", output.path
        ] + swiftFiles
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let diagnostic = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, "Generated Swift did not compile:\n\(diagnostic)")
    }

    @MainActor
    func testExportWritesSwiftPackage() throws {
        let specification = try String(contentsOf: exampleURL, encoding: .utf8)
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: GeneratorOptions(accessLevel: .public),
            sourceLabel: "ExampleSpec.json"
        )

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpecForgeExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        try ExportService.write(result: result, to: temporary)

        let package = temporary.appendingPathComponent("Package.swift")
        let models = temporary.appendingPathComponent("Sources/OrbitTasksAPIKit/Models.swift")
        let endpoints = temporary.appendingPathComponent("Sources/OrbitTasksAPIKit/Endpoints.swift")
        let readme = temporary.appendingPathComponent("README.md")

        XCTAssertTrue(FileManager.default.fileExists(atPath: package.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: models.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: endpoints.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: readme.path))
        XCTAssertTrue(try String(contentsOf: models, encoding: .utf8).contains("public struct Task"))
        XCTAssertTrue(try String(contentsOf: readme, encoding: .utf8).contains("OrbitTasksAPIKit"))
    }

    func testFlatOutputWithoutPackageOrReadme() throws {
        let specification = try String(contentsOf: swaggerURL, encoding: .utf8)
        var options = GeneratorOptions(accessLevel: .internal)
        options.includePackageManifest = false
        options.includeReadme = false
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: options,
            sourceLabel: "swagger2.yaml"
        )

        XCTAssertTrue(result.files.contains { $0.path == "Models.swift" })
        XCTAssertTrue(result.files.contains { $0.path == "Endpoints.swift" })
        XCTAssertFalse(result.files.contains { $0.name == "Package.swift" })
        XCTAssertFalse(result.files.contains { $0.name == "README.md" })
        XCTAssertFalse(result.files.contains { $0.path.hasPrefix("Sources/") })
    }

    @MainActor
    func testExportedPackageBuildsWithSwiftPM() throws {
        let specification = try String(contentsOf: exampleURL, encoding: .utf8)
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: GeneratorOptions(accessLevel: .public),
            sourceLabel: "ExampleSpec.json"
        )

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpecForgePackage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try ExportService.write(result: result, to: temporary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swift", "build",
            "--package-path", temporary.path,
            "-c", "debug"
        ]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let diagnostic = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, "Generated package did not build:\n\(diagnostic)")
    }

    func testTypePrefixIsApplied() throws {
        let specification = try String(contentsOf: swaggerURL, encoding: .utf8)
        var options = GeneratorOptions(accessLevel: .public)
        options.typePrefix = "ACME"
        let result = try SwiftGenerator.generate(
            specification: specification,
            options: options,
            sourceLabel: "swagger2.yaml"
        )
        let models = try XCTUnwrap(result.files.first { $0.name == "Models.swift" }?.content)
        XCTAssertTrue(models.contains("public struct ACMEPet: Codable"))
        XCTAssertTrue(models.contains("public struct ACMEOwner: Codable"))
    }
}
