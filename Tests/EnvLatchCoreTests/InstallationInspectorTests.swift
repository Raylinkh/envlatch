import Foundation
import Testing
@testable import EnvLatchCore

@Suite("AK-5 and AK-6 one-time pairing")
struct InstallationInspectorTests {
    @Test func distinguishesCorrectMissingAndStaleLinks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-install-\(UUID().uuidString)", isDirectory: true)
        let executable = root.appendingPathComponent("EnvLatch")
        let otherExecutable = root.appendingPathComponent("Other")
        let link = root.appendingPathComponent("bin/envlatch")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        FileManager.default.createFile(atPath: otherExecutable.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: root) }

        let skillFiles = [
            root.appendingPathComponent(".agents/skills/envlatch/SKILL.md"),
            root.appendingPathComponent(".codex/skills/envlatch/SKILL.md"),
            root.appendingPathComponent(".claude/skills/envlatch/SKILL.md"),
            root.appendingPathComponent(".gemini/skills/envlatch/SKILL.md"),
        ]
        let pairScript = root.appendingPathComponent("EnvLatch.app/Contents/Resources/pair-agents.sh")
        let bundledSkill = pairScript.deletingLastPathComponent()
            .appendingPathComponent("envlatch-skill/SKILL.md")
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

        let prompt = inspector.setupPrompt
        #expect(prompt.contains("envlatch pair \"<your agent or host name>\""))
        #expect(prompt.contains("envlatch doctor"))
        #expect(prompt.contains("envlatch help"))
        #expect(prompt.contains("envlatch groups"))
        #expect(prompt.contains("Any saved key works directly with `--using`"))
        #expect(prompt.contains("envlatch run --using <saved-key> --using <saved-key>"))
        #expect(prompt.contains("envlatch groups create \"<group-name>\""))
        #expect(prompt.contains("envlatch run --using <saved-key-or-group> -- <program> [args...]"))
        #expect(prompt.contains("Never silently use broad `envlatch run --`"))
        #expect(prompt.contains("this is not authorization"))
        #expect(prompt.contains("Group creation accepts saved key names only"))
        #expect(prompt.contains("Never print, reveal, export, or write secret values"))

        try Data("stale skill".utf8).write(to: skillFiles[0])
        #expect(inspector.pairingStatus() == .incomplete)
        #expect(inspector.pairCommand.contains(" pair \"<your agent or host name>\""))
    }
}
