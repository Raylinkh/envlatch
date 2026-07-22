import Foundation

public struct CLIApplication {
    private let store: any SecretStore
    private let environment: [String: String]
    private let inspector: InstallationInspector
    private let identityProvider: () -> String
    private let stdout: (String) -> Void
    private let stderr: (String) -> Void

    public init(
        store: any SecretStore = KeychainSecretStore(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        inspector: InstallationInspector = .current(),
        identityProvider: @escaping () -> String = CodeIdentity.currentDesignatedRequirement,
        stdout: @escaping (String) -> Void = CLIApplication.standardOutput,
        stderr: @escaping (String) -> Void = CLIApplication.standardError
    ) {
        self.store = store
        self.environment = environment
        self.inspector = inspector
        self.identityProvider = identityProvider
        self.stdout = stdout
        self.stderr = stderr
    }

    public func run(arguments: [String]) -> Int32 {
        do {
            switch try CLIParser.parse(arguments) {
            case .list:
                try store.listNames().forEach { stdout($0.rawValue) }
                return 0
            case .doctor:
                let names = try store.listNames()
                stdout("platform=macOS")
                stdout("keychain_attribute_query=reachable")
                stdout("saved_key_count=\(names.count)")
                stdout("candidate_requirement=\(identityProvider())")
                stdout("cli_link=\(linkStatusDescription(inspector.linkStatus()))")
                stdout("agent_pairing=\(pairingStatusDescription(inspector.pairingStatus()))")
                stdout("pair_command=\(inspector.pairCommand)")
                return 0
            case .run(let program, let programArguments):
                let plan = try prepareRun(program: program, arguments: programArguments)
                CommandRunner.execute(plan)
            case .help:
                stdout(Self.usage)
                return 0
            }
        } catch let error as CLIParseError {
            stderr("error: \(error.localizedDescription)")
            stderr(Self.usage)
            return 64
        } catch let error as PathResolutionError {
            stderr("error: \(error.localizedDescription)")
            return 127
        } catch {
            stderr("error: \(error.localizedDescription)")
            return 1
        }
    }

    public func prepareRun(program: String, arguments: [String]) throws -> ExecutionPlan {
        let names = try store.listNames()
        guard !names.isEmpty else {
            throw ExecutionPlanError.emptyCredentials
        }

        let resolvedExecutable = try PathResolver.resolve(
            program: program,
            inheritedPath: environment["PATH"]
        )
        let credentials = try store.loadAll()
        return try ExecutionPlan.make(
            resolvedExecutable: resolvedExecutable,
            originalProgram: program,
            arguments: arguments,
            inheritedEnvironment: environment,
            credentials: credentials
        )
    }

    public static let usage = """
    Usage:
      agent-keyring list
      agent-keyring doctor
      agent-keyring run -- <program> [args...]
    """

    private func linkStatusDescription(_ status: CLILinkStatus) -> String {
        switch status {
        case .installed:
            "installed"
        case .missing:
            "missing"
        case .stale(let destination):
            "stale:\(destination)"
        }
    }

    private func pairingStatusDescription(_ status: AgentPairingStatus) -> String {
        switch status {
        case .paired:
            "paired"
        case .incomplete:
            "incomplete"
        }
    }

    public static func standardOutput(_ text: String) {
        FileHandle.standardOutput.write(Data("\(text)\n".utf8))
    }

    public static func standardError(_ text: String) {
        FileHandle.standardError.write(Data("\(text)\n".utf8))
    }
}
