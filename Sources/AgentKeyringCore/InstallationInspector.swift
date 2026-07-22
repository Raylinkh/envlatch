import Foundation

public enum CLILinkStatus: Equatable, Sendable {
    case installed
    case missing
    case stale(resolvesTo: String)
}

public enum AgentPairingStatus: Equatable, Sendable {
    case paired
    case incomplete
}

public struct InstallationInspector: Sendable {
    public let executableURL: URL
    public let linkURL: URL
    public let skillFileURLs: [URL]
    public let pairScriptURL: URL

    public init(
        executableURL: URL,
        linkURL: URL,
        skillFileURLs: [URL] = [],
        pairScriptURL: URL? = nil
    ) {
        let resolvedExecutable = executableURL.standardizedFileURL.resolvingSymlinksInPath()
        self.executableURL = resolvedExecutable
        self.linkURL = linkURL
        self.skillFileURLs = skillFileURLs
        self.pairScriptURL = pairScriptURL
            ?? resolvedExecutable.deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/pair-agents.sh")
    }

    public static func current() -> InstallationInspector {
        let executable = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let link = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/agent-keyring")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let skillFiles = [".agents", ".codex", ".claude", ".gemini"].map {
            home.appendingPathComponent($0)
                .appendingPathComponent("skills/agent-keyring/SKILL.md")
        }
        return InstallationInspector(
            executableURL: executable,
            linkURL: link,
            skillFileURLs: skillFiles
        )
    }

    public func linkStatus() -> CLILinkStatus {
        guard FileManager.default.fileExists(atPath: linkURL.path) else {
            return .missing
        }
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path) else {
            return .stale(resolvesTo: linkURL.path)
        }

        let destinationURL: URL
        if destination.hasPrefix("/") {
            destinationURL = URL(fileURLWithPath: destination)
        } else {
            destinationURL = URL(
                fileURLWithPath: destination,
                relativeTo: linkURL.deletingLastPathComponent()
            )
        }

        let resolvedDestination = destinationURL.standardizedFileURL.resolvingSymlinksInPath().path
        let resolvedExecutable = executableURL.standardizedFileURL.resolvingSymlinksInPath().path
        return resolvedDestination == resolvedExecutable
            ? .installed
            : .stale(resolvesTo: resolvedDestination)
    }

    public func pairingStatus() -> AgentPairingStatus {
        guard linkStatus() == .installed, !skillFileURLs.isEmpty else {
            return .incomplete
        }

        let fileManager = FileManager.default
        let canonicalFile = skillFileURLs[0].standardizedFileURL
        let canonicalDirectory = canonicalFile.deletingLastPathComponent()
        let bundledFile = pairScriptURL.deletingLastPathComponent()
            .appendingPathComponent("agent-keyring-skill/SKILL.md")

        guard fileManager.isExecutableFile(atPath: pairScriptURL.path),
              (try? fileManager.destinationOfSymbolicLink(atPath: canonicalDirectory.path)) == nil,
              let canonicalData = try? Data(contentsOf: canonicalFile),
              let bundledData = try? Data(contentsOf: bundledFile),
              canonicalData == bundledData else {
            return .incomplete
        }

        return .paired
    }

    public var pairCommand: String {
        let executable = linkStatus() == .installed
            ? "agent-keyring"
            : shellQuote(executableURL.path)
        return "\(executable) pair \"<your agent or host name>\""
    }

    public var sharedSkillURL: URL {
        if let canonical = skillFileURLs.first {
            return canonical.deletingLastPathComponent()
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agents/skills/agent-keyring")
    }

    public var setupPrompt: String {
        """
        Set up this agent or host with AgentKeyring on this Mac.

        1. Choose a short name for yourself, then run:
           \(pairCommand)
        2. Run `agent-keyring doctor` and confirm `agent_pairing=paired`.
        3. Run `agent-keyring help` and follow its usage.
        4. Run `agent-keyring profiles` to find saved endpoint profiles.
        5. When a command needs a profiled credential, run it exactly as:
           agent-keyring run --using <profile-name> -- <program> [args...]
           Otherwise use: agent-keyring run -- <program> [args...]

        Use `agent-keyring list` only to check saved environment-variable names. Never print, reveal, export, or write secret values to files or shell profiles.
        """
    }

    public func bundleInvocation(program: String) -> String {
        "\(shellQuote(executableURL.path)) run -- \(shellQuote(program))"
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
