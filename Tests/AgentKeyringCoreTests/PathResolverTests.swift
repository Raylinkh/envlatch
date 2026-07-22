import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-3 executable resolution")
struct PathResolverTests {
    @Test func resolvesBareProgramFromInheritedPath() throws {
        #expect(try PathResolver.resolve(program: "sh", inheritedPath: "/usr/bin:/bin") == "/bin/sh")
    }

    @Test func acceptsExecutableAbsolutePath() throws {
        #expect(try PathResolver.resolve(program: "/usr/bin/true", inheritedPath: nil) == "/usr/bin/true")
    }

    @Test func rejectsMissingNonExecutableAndEmptyPathSegments() throws {
        let temporaryFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-nonexec-\(UUID().uuidString)")
        try Data("not executable".utf8).write(to: temporaryFile)
        defer { try? FileManager.default.removeItem(at: temporaryFile) }

        #expect(throws: PathResolutionError.self) {
            try PathResolver.resolve(program: temporaryFile.path, inheritedPath: nil)
        }
        #expect(throws: PathResolutionError.self) {
            try PathResolver.resolve(program: "codex", inheritedPath: ":/usr/bin")
        }
        #expect(throws: PathResolutionError.self) {
            try PathResolver.resolve(program: "definitely-not-a-real-command", inheritedPath: "/usr/bin:/bin")
        }
    }
}
