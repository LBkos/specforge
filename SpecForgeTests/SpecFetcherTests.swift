import Darwin
import XCTest
@testable import SpecForge

final class SpecFetcherTests: XCTestCase {
    func testBearerAuthentication() async throws {
        let server = try LocalSpecServer()
        defer { server.stop() }

        var auth = AuthConfiguration()
        auth.kind = .bearer
        auth.bearerToken = "test-token"

        let fetched = try await server.fetch(path: "/bearer", auth: auth)
        XCTAssertTrue(fetched.text.contains("\"title\": \"Auth Fixture\""))
    }

    func testAPIKeyHeaderAuthentication() async throws {
        let server = try LocalSpecServer()
        defer { server.stop() }

        var auth = AuthConfiguration()
        auth.kind = .apiKey
        auth.apiKeyName = "X-API-Key"
        auth.apiKeyValue = "secret-key"
        auth.apiKeyLocation = .header

        let fetched = try await server.fetch(path: "/api-header", auth: auth)
        XCTAssertTrue(fetched.text.contains("Auth Fixture"))
    }

    func testAPIKeyQueryAuthentication() async throws {
        let server = try LocalSpecServer()
        defer { server.stop() }

        var auth = AuthConfiguration()
        auth.kind = .apiKey
        auth.apiKeyName = "api_key"
        auth.apiKeyValue = "secret-key"
        auth.apiKeyLocation = .query

        let fetched = try await server.fetch(path: "/api-query", auth: auth)
        XCTAssertTrue(fetched.text.contains("Auth Fixture"))
    }

    func testBasicAuthenticationAndUnauthorizedResponse() async throws {
        let server = try LocalSpecServer()
        defer { server.stop() }

        var auth = AuthConfiguration()
        auth.kind = .basic
        auth.username = "user"
        auth.password = "password"

        let fetched = try await server.fetch(path: "/basic", auth: auth)
        XCTAssertTrue(fetched.text.contains("Auth Fixture"))

        var wrong = AuthConfiguration()
        wrong.kind = .bearer
        wrong.bearerToken = "wrong-token"
        do {
            _ = try await server.fetch(path: "/bearer", auth: wrong)
            XCTFail("Expected an unauthorized error")
        } catch let error as SpecFetchError {
            guard case .unauthorized(401) = error else {
                return XCTFail("Expected HTTP 401, got \(error)")
            }
        }
    }
}

private final class LocalSpecServer {
    private let process: Process
    private let port: Int

    init() throws {
        port = Int.random(in: 43100...48900)
        let script = """
        import base64, json, sys
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from urllib.parse import urlparse, parse_qs

        SPEC = {
            "openapi": "3.0.3",
            "info": {"title": "Auth Fixture", "version": "1.0.0"},
            "paths": {}
        }
        BODY = json.dumps(SPEC).encode("utf-8")

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                parsed = urlparse(self.path)
                authorized = False
                if parsed.path == "/bearer":
                    authorized = self.headers.get("Authorization") == "Bearer test-token"
                elif parsed.path == "/api-header":
                    authorized = self.headers.get("X-API-Key") == "secret-key"
                elif parsed.path == "/api-query":
                    authorized = parse_qs(parsed.query).get("api_key") == ["secret-key"]
                elif parsed.path == "/basic":
                    expected = "Basic " + base64.b64encode(b"user:password").decode()
                    authorized = self.headers.get("Authorization") == expected

                if not authorized:
                    self.send_response(401)
                    self.end_headers()
                    return

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(BODY)))
                self.end_headers()
                self.wfile.write(BODY)

            def log_message(self, format, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", \(port)), Handler)
        print("READY", flush=True)
        server.serve_forever()
        """
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpecForgeServer-\(UUID().uuidString).py")
        try script.write(to: temporary, atomically: true, encoding: .utf8)
        process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [temporary.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        // The server binds to localhost in a few milliseconds. Give it a moment
        // before the first request, then allow retries in fetch(path:auth:).
        Thread.sleep(forTimeInterval: 0.8)
    }

    func fetch(path: String, auth: AuthConfiguration) async throws -> FetchedSpecification {
        var lastError: Error?
        for _ in 0..<12 {
            do {
                return try await SpecFetcher.fetch(
                    urlString: "http://127.0.0.1:\(port)\(path)",
                    auth: auth
                )
            } catch {
                lastError = error
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
        throw lastError ?? SpecFetchError.transport("The fixture server did not start.")
    }

    func stop() {
        guard process.isRunning else { return }
        process.terminate()
        for _ in 0..<20 {
            if !process.isRunning { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        kill(process.processIdentifier, SIGKILL)
    }
}
