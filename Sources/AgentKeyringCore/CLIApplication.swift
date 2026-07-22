import Foundation

public struct CLIApplication {
    private let store: any SecretStore
    private let environment: [String: String]
    private let inspector: InstallationInspector
    private let pairedHostStore: PairedHostStore
    private let pairInstaller: any PairInstalling
    private let endpointProfileStore: EndpointProfileStore
    private let identityProvider: () -> String
    private let stdout: (String) -> Void
    private let stderr: (String) -> Void

    public init(
        store: any SecretStore = KeychainSecretStore(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        inspector: InstallationInspector = .current(),
        pairedHostStore: PairedHostStore = .current(),
        pairInstaller: any PairInstalling = PairScriptInstaller(),
        endpointProfileStore: EndpointProfileStore = .current(),
        identityProvider: @escaping () -> String = CodeIdentity.currentDesignatedRequirement,
        stdout: @escaping (String) -> Void = CLIApplication.standardOutput,
        stderr: @escaping (String) -> Void = CLIApplication.standardError
    ) {
        self.store = store
        self.environment = environment
        self.inspector = inspector
        self.pairedHostStore = pairedHostStore
        self.pairInstaller = pairInstaller
        self.endpointProfileStore = endpointProfileStore
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
            case .profiles:
                try endpointProfileStore.list().forEach {
                    stdout("\($0.providerName)\tkey=\($0.credentialName.rawValue)\tcontract=\($0.contract.rawValue)\tbase_url=\($0.baseURL)")
                }
                return 0
            case .doctor:
                let names = try store.listNames()
                let pairedHosts = try pairedHostStore.list()
                let profiles = try endpointProfileStore.list()
                stdout("platform=macOS")
                stdout("keychain_attribute_query=reachable")
                stdout("saved_key_count=\(names.count)")
                stdout("candidate_requirement=\(identityProvider())")
                stdout("cli_link=\(linkStatusDescription(inspector.linkStatus()))")
                stdout("agent_pairing=\(pairingStatusDescription(inspector.pairingStatus()))")
                stdout("paired_host_count=\(pairedHosts.count)")
                pairedHosts.forEach { stdout("paired_host=\($0.name)") }
                stdout("endpoint_profile_count=\(profiles.count)")
                stdout("pair_command=\(inspector.pairCommand)")
                return 0
            case .pair(let name):
                try pairInstaller.install(scriptURL: inspector.pairScriptURL, environment: environment)
                let host = try pairedHostStore.register(name: name)
                stdout("paired_host=\(host.name)")
                stdout("shared_skill=\(inspector.sharedSkillURL.path)")
                stdout("next=agent-keyring doctor")
                return 0
            case .run(let profile, let program, let programArguments):
                let plan = try prepareRun(
                    profile: profile,
                    program: program,
                    arguments: programArguments
                )
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
        try prepareRun(profile: nil, program: program, arguments: arguments)
    }

    public func prepareRun(
        profile profileIdentifier: String?,
        program: String,
        arguments: [String]
    ) throws -> ExecutionPlan {
        let resolvedExecutable = try PathResolver.resolve(
            program: program,
            inheritedPath: environment["PATH"]
        )

        let credentials: [String: String]
        let configuration: [String: String]
        if let profileIdentifier {
            let profile = try endpointProfileStore.profile(named: profileIdentifier)
            let value = try store.load(name: profile.credentialName)
            credentials = Dictionary(
                uniqueKeysWithValues: profile.secretEnvironmentNames.map { ($0, value) }
            )
            configuration = profile.configurationEnvironment
        } else {
            let names = try store.listNames()
            guard !names.isEmpty else {
                throw ExecutionPlanError.emptyCredentials
            }
            credentials = try store.loadAll()
            configuration = [:]
        }
        return try ExecutionPlan.make(
            resolvedExecutable: resolvedExecutable,
            originalProgram: program,
            arguments: arguments,
            inheritedEnvironment: environment,
            credentials: credentials,
            configuration: configuration
        )
    }

    public static let usage = """
    Usage:
      agent-keyring list
      agent-keyring profiles
      agent-keyring doctor
      agent-keyring pair <agent-or-host-name>
      agent-keyring run -- <program> [args...]
      agent-keyring run --using <profile-name> -- <program> [args...]
      agent-keyring help
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
