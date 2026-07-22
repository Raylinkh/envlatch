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
        return skillFileURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
            ? .paired
            : .incomplete
    }

    public var pairCommand: String {
        shellQuote(pairScriptURL.path)
    }

    public func bundleInvocation(program: String) -> String {
        "\(shellQuote(executableURL.path)) run -- \(shellQuote(program))"
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
