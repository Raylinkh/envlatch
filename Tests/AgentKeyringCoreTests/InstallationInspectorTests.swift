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
        for skillFile in skillFiles {
            try FileManager.default.createDirectory(
                at: skillFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: skillFile.path, contents: Data())
        }
        #expect(inspector.pairingStatus() == .paired)
        #expect(inspector.pairCommand.contains("pair-agents.sh"))
        #expect(inspector.bundleInvocation(program: "codex").hasSuffix(" run -- 'codex'"))
    }
}
