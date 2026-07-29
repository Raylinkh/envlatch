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
            .appendingPathComponent(".local/bin/envlatch")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let skillFiles = [".agents", ".codex", ".claude", ".gemini"].map {
            home.appendingPathComponent($0)
                .appendingPathComponent("skills/envlatch/SKILL.md")
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
            .appendingPathComponent("envlatch-skill/SKILL.md")

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
            ? "envlatch"
            : shellQuote(executableURL.path)
        return "\(executable) pair \"<your agent or host name>\""
    }

    public var sharedSkillURL: URL {
        if let canonical = skillFileURLs.first {
            return canonical.deletingLastPathComponent()
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agents/skills/envlatch")
    }

    public var setupPrompt: String {
        """
        Set up this agent or host with EnvLatch on this Mac.

        1. Optionally register a short display name for setup status (this is not authorization):
           \(pairCommand)
        2. Run `envlatch doctor` and confirm `agent_pairing=paired`.
           `saved_key_count` is current-process visibility only. If the user expects saved keys and the count is zero, do not conclude that the vault is empty. When doctor exits nonzero with `keychain_visibility_warning=sandboxed_zero_is_inconclusive`, re-run doctor—and the eventual `envlatch run ...` command—through the host's normal approval path with normal macOS Keychain access. Do not ask the user to recreate keys based on a sandboxed zero.
        3. Run `envlatch help` and follow its usage.
        4. Run `envlatch list` to see saved key names. Any saved key works directly with `--using`.
        5. If one command needs several saved keys once, repeat `--using` with exact saved key names:
           envlatch run --using <saved-key> --using <saved-key> -- <program> [args...]
        6. For a reusable combination, create a non-secret key group:
           envlatch groups create "<group-name>" --using <saved-key> --using <saved-key>
           Run `envlatch groups` to inspect saved group membership and endpoint bindings.
        7. Run a single saved key or reusable group exactly as:
           envlatch run --using <saved-key-or-group> -- <program> [args...]
           If a required saved key is missing, ask the user to add it in the EnvLatch GUI. Never silently use broad `envlatch run --`, which exposes every saved key.

        Group creation accepts saved key names only and never reads their values. Pairing is status, not authorization. Never print, reveal, export, or write secret values to files or shell profiles.
        """
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
