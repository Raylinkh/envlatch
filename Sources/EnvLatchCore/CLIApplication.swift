import Foundation

public struct CLIApplication {
    private let store: any SecretStore
    private let environment: [String: String]
    private let inspector: InstallationInspector
    private let pairedHostStore: PairedHostStore
    private let pairInstaller: any PairInstalling
    private let endpointProfileStore: EndpointProfileStore
    private let launchProfileStore: LaunchProfileStore
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
        launchProfileStore: LaunchProfileStore = .current(),
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
        self.launchProfileStore = launchProfileStore
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
                let endpoints = try endpointProfileStore.list()
                try launchProfileStore.list().forEach { launchProfile in
                    stdout("\(launchProfile.name)\tkeys=\(launchProfile.credentialNames.map(\.rawValue).joined(separator: ","))")
                    launchProfile.credentialNames.forEach { credential in
                        if let endpoint = endpoints.first(where: { $0.credentialName == credential }) {
                            stdout("  \(credential.rawValue)\ttarget=\(endpoint.credentialEnvironmentName.rawValue)\tcontract=\(endpoint.contract.rawValue)\tbase_url=\(endpoint.baseURL)")
                        }
                    }
                }
                return 0
            case .createGroup(let name, let rawCredentialNames):
                let profile = try createGroup(
                    name: name,
                    rawCredentialNames: rawCredentialNames
                )
                stdout("created_group=\(profile.name)")
                stdout("keys=\(profile.credentialNames.map(\.rawValue).joined(separator: ","))")
                return 0
            case .doctor:
                let names = try store.listNames()
                let pairedHosts = try pairedHostStore.list()
                let profiles = try endpointProfileStore.list()
                let launchProfiles = try launchProfileStore.list()
                let identity = identityProvider()
                stdout("platform=macOS")
                stdout("keychain_attribute_query=reachable")
                stdout("saved_key_count=\(names.count)")
                stdout("saved_key_count_scope=current_process")
                let sandboxedZeroIsInconclusive =
                    names.isEmpty && isKnownSandboxedExecution
                if sandboxedZeroIsInconclusive {
                    stdout("keychain_visibility_warning=sandboxed_zero_is_inconclusive")
                }
                stdout("candidate_requirement=\(identity)")
                stdout("cli_link=\(linkStatusDescription(inspector.linkStatus()))")
                stdout("agent_pairing=\(pairingStatusDescription(inspector.pairingStatus()))")
                stdout("paired_host_count=\(pairedHosts.count)")
                pairedHosts.forEach { stdout("paired_host=\($0.name)") }
                stdout("endpoint_profile_count=\(profiles.count)")
                stdout("launch_profile_count=\(launchProfiles.count)")
                stdout("pair_command=\(inspector.pairCommand)")
                guard !sandboxedZeroIsInconclusive else {
                    stderr(
                        "error: EnvLatch cannot confirm an empty vault from this sandboxed process. " +
                        "Re-run this EnvLatch command with normal macOS Keychain access; " +
                        "do not conclude that no keys are saved."
                    )
                    return 1
                }
                guard !identity.hasPrefix("unavailable:") else {
                    stderr("error: EnvLatch could not read its code identity.")
                    return 1
                }
                return 0
            case .version:
                stdout("EnvLatch \(ProductInfo.version)")
                return 0
            case .pair(let name):
                try pairInstaller.install(scriptURL: inspector.pairScriptURL, environment: environment)
                let host = try pairedHostStore.register(name: name)
                stdout("paired_host=\(host.name)")
                stdout("shared_skill=\(inspector.sharedSkillURL.path)")
                stdout("next=envlatch doctor")
                return 0
            case .run(let selections, let program, let programArguments):
                let plan = try prepareRun(
                    selections: selections,
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
        try prepareRun(selections: nil, program: program, arguments: arguments)
    }

    public func prepareRun(
        profile selectionIdentifier: String?,
        program: String,
        arguments: [String]
    ) throws -> ExecutionPlan {
        try prepareRun(
            selections: selectionIdentifier.map { [$0] },
            program: program,
            arguments: arguments
        )
    }

    public func prepareRun(
        selections selectionIdentifiers: [String]?,
        program: String,
        arguments: [String]
    ) throws -> ExecutionPlan {
        let resolvedExecutable = try PathResolver.resolve(
            program: program,
            inheritedPath: environment["PATH"]
        )

        let credentials: [String: String]
        let configuration: [String: String]
        if let selectionIdentifiers {
            let availableNames = try store.listNames()
            let groups = try launchProfileStore.list()
            let selectedNames = try resolveSelectionIdentifiers(
                selectionIdentifiers,
                availableNames: availableNames,
                groups: groups
            )
            let bindingPlan = try makeBindingPlan(for: selectedNames)

            var selectedCredentials: [String: String] = [:]
            for binding in bindingPlan.bindings {
                let value = try store.load(name: binding.source)
                for target in binding.targets {
                    selectedCredentials[target] = value
                }
            }
            credentials = selectedCredentials
            configuration = bindingPlan.configuration
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
      envlatch list
      envlatch groups
      envlatch groups create <group-name> --using <saved-key> [--using <saved-key> ...]
      envlatch doctor
      envlatch version
      envlatch pair <agent-or-host-name>
      envlatch help

    Preferred least privilege:
      envlatch run --using <saved-key-or-group> -- <program> [args...]
      envlatch run --using <saved-key> --using <saved-key> -- <program> [args...]

    Broad compatibility (exposes every saved key):
      envlatch run -- <program> [args...]
    """

    private struct SecretBinding {
        let source: CredentialName
        let targets: [String]
    }

    private struct BindingPlan {
        let bindings: [SecretBinding]
        let configuration: [String: String]
    }

    private var isKnownSandboxedExecution: Bool {
        [
            "APP_SANDBOX_CONTAINER_ID",
            "CODEX_SANDBOX",
            "SANDBOXED",
        ].contains { name in
            guard let value = environment[name]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            else {
                return false
            }
            return !value.isEmpty && !["0", "false", "no"].contains(value)
        }
    }

    private func createGroup(
        name: String,
        rawCredentialNames: [String]
    ) throws -> LaunchProfile {
        let profile = try LaunchProfile(
            name: name,
            credentialNames: try rawCredentialNames.map(CredentialName.init(validating:))
        )
        let availableNames = try store.listNames()
        let existingGroups = try launchProfileStore.listWithoutMigrating()
        if availableNames.contains(where: {
            $0.rawValue.caseInsensitiveCompare(profile.name) == .orderedSame
        }) {
            throw LaunchProfileError.ambiguousSelection(profile.name)
        }
        if existingGroups.contains(where: {
            $0.name.caseInsensitiveCompare(profile.name) == .orderedSame
        }) {
            throw LaunchProfileError.profileAlreadyExists(profile.name)
        }

        let available = Set(availableNames)
        for credential in profile.credentialNames where !available.contains(credential) {
            throw LaunchProfileError.missingCredential(
                profile: profile.name,
                credential: credential.rawValue
            )
        }
        _ = try makeBindingPlan(for: profile.credentialNames)
        try launchProfileStore.create(profile)
        return profile
    }

    private func resolveSelectionIdentifiers(
        _ identifiers: [String],
        availableNames: [CredentialName],
        groups: [LaunchProfile]
    ) throws -> [CredentialName] {
        guard !identifiers.isEmpty else {
            throw CLIParseError.missingProfile
        }
        let available = Set(availableNames)
        var selected: [CredentialName] = []
        var seen: Set<CredentialName> = []
        var seenIdentifiers: Set<String> = []

        for identifier in identifiers {
            guard seenIdentifiers.insert(identifier).inserted else {
                throw LaunchProfileError.duplicateSelection(identifier)
            }
            let exactCredential = availableNames.first {
                $0.rawValue == identifier
            }
            let collidingCredential = availableNames.first {
                $0.rawValue.caseInsensitiveCompare(identifier) == .orderedSame
            }
            let matchingGroup = groups.first {
                $0.name.caseInsensitiveCompare(identifier) == .orderedSame
            }
            if collidingCredential != nil, matchingGroup != nil {
                throw LaunchProfileError.ambiguousSelection(identifier)
            }
            if identifiers.count > 1, matchingGroup != nil {
                throw LaunchProfileError.groupCannotBeCombined(identifier)
            }

            let candidates: [CredentialName]
            let selectionName: String
            if let exactCredential {
                candidates = [exactCredential]
                selectionName = exactCredential.rawValue
            } else if let matchingGroup {
                candidates = matchingGroup.credentialNames
                selectionName = matchingGroup.name
            } else {
                throw LaunchProfileError.profileNotFound(identifier)
            }

            for credential in candidates {
                guard available.contains(credential) else {
                    throw LaunchProfileError.missingCredential(
                        profile: selectionName,
                        credential: credential.rawValue
                    )
                }
                if seen.insert(credential).inserted {
                    selected.append(credential)
                }
            }
        }
        return selected
    }

    private func makeBindingPlan(
        for selectedNames: [CredentialName]
    ) throws -> BindingPlan {
        let endpoints = Dictionary(
            uniqueKeysWithValues: try endpointProfileStore.list().map { ($0.credentialName, $0) }
        )
        var targetOwners: [String: CredentialName] = [:]
        var configuration: [String: String] = [:]
        var bindings: [SecretBinding] = []

        for source in selectedNames {
            let endpoint = endpoints[source]
            let targets = endpoint?.secretEnvironmentNames ?? [source.rawValue]
            for target in targets {
                if let owner = targetOwners[target], owner != source {
                    throw LaunchProfileError.conflictingSecretEnvironment(
                        name: target,
                        first: owner.rawValue,
                        second: source.rawValue
                    )
                }
                targetOwners[target] = source
            }
            for (name, value) in endpoint?.configurationEnvironment ?? [:] {
                if let existing = configuration[name], existing != value {
                    throw LaunchProfileError.conflictingConfigurationEnvironment(name: name)
                }
                configuration[name] = value
            }
            bindings.append(SecretBinding(source: source, targets: targets))
        }
        return BindingPlan(bindings: bindings, configuration: configuration)
    }

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
