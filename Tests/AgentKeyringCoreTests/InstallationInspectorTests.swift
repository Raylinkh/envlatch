import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-5 and AK-6 one-time pairing")
struct InstallationInspectorTests {
    @Test func distinguishesCorrectMissingAndStaleLinks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-install-\(UUID().uuidString)", isDirectory: true)
        let executable = root.appendingPathComponent("AgentKeyring")
        let otherExecutable = root.appendingPathComponent("Other")
        let link = root.appendingPathComponent("bin/agent-keyring")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        FileManager.default.createFile(atPath: otherExecutable.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: root) }

        let skillFiles = [
            root.appendingPathComponent(".agents/skills/agent-keyring/SKILL.md"),
            root.appendingPathComponent(".codex/skills/agent-keyring/SKILL.md"),
            root.appendingPathComponent(".claude/skills/agent-keyring/SKILL.md"),
            root.appendingPathComponent(".gemini/skills/agent-keyring/SKILL.md"),
        ]
        let pairScript = root.appendingPathComponent("AgentKeyring.app/Contents/Resources/pair-agents.sh")
        let bundledSkill = pairScript.deletingLastPathComponent()
            .appendingPathComponent("agent-keyring-skill/SKILL.md")
        let inspector = InstallationInspector(
            executableURL: executable,
            linkURL: link,
            skillFileURLs: skillFiles,
            pairScriptURL: pairScript
        )
        #expect(inspector.linkStatus() == .missing)
        #expect(inspector.pairingStatus() == .incomplete)

        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: otherExecutable)
        #expect(inspector.linkStatus() == .stale(resolvesTo: otherExecutable.path))

        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)
        #expect(inspector.linkStatus() == .installed)

        let symlinkLaunchedInspector = InstallationInspector(executableURL: link, linkURL: link)
        #expect(symlinkLaunchedInspector.executableURL.path == executable.path)
        try FileManager.default.createDirectory(
            at: bundledSkill.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("shared skill".utf8).write(to: bundledSkill)
        FileManager.default.createFile(atPath: pairScript.path, contents: Data())
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: pairScript.path
        )

        let canonicalDirectory = skillFiles[0].deletingLastPathComponent()
        try FileManager.default.createDirectory(at: canonicalDirectory, withIntermediateDirectories: true)
        try Data("shared skill".utf8).write(to: skillFiles[0])
        for skillFile in skillFiles.dropFirst() {
            try FileManager.default.createDirectory(
                at: skillFile.deletingLastPathComponent().deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createSymbolicLink(
                at: skillFile.deletingLastPathComponent(),
                withDestinationURL: canonicalDirectory
            )
        }
        #expect(inspector.pairingStatus() == .paired)

        try Data("stale skill".utf8).write(to: skillFiles[0])
        #expect(inspector.pairingStatus() == .incomplete)
        #expect(inspector.pairCommand.contains("pair-agents.sh"))
        #expect(inspector.bundleInvocation(program: "codex").hasSuffix(" run -- 'codex'"))
    }
}
