import Foundation
import Testing
@testable import EnvLatchCore

@Suite("AK-3 executable resolution")
struct PathResolverTests {
    @Test func resolvesBareProgramFromInheritedPath() throws {
        #expect(try PathResolver.resolve(program: "sh", inheritedPath: "/usr/bin:/bin") == "/bin/sh")
    }

    @Test func acceptsExecutableAbsolutePath() throws {
        #expect(try PathResolver.resolve(program: "/usr/bin/true", inheritedPath: nil) == "/usr/bin/true")
    }

    @Test func resolvesExecutableSymlinkToCanonicalRegularFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("real-agent")
        let link = root.appendingPathComponent("agent-tool")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: target.path)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(
            try PathResolver.resolve(program: "agent-tool", inheritedPath: root.path)
                == target.resolvingSymlinksInPath().standardizedFileURL.path
        )
    }

    @Test func rejectsMissingNonExecutableAndEmptyPathSegments() throws {
        let temporaryFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-nonexec-\(UUID().uuidString)")
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
