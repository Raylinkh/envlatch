import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-3 and AK-6 CLI behavior", .serialized)
struct CLIApplicationTests {
    @Test func listAndDoctorNeverReadSecretValues() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "OPENAI_API_KEY")],
            values: ["OPENAI_API_KEY": "must-not-be-read"]
        )
        var output: [String] = []
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring"),
                linkURL: URL(fileURLWithPath: "/definitely/missing/agent-keyring")
            ),
            identityProvider: { "identifier test" },
            stdout: { output.append($0) },
            stderr: { _ in }
        )

        #expect(application.run(arguments: ["list"]) == 0)
        #expect(application.run(arguments: ["doctor"]) == 0)
        #expect(store.loadAllCallCount == 0)
        #expect(output.contains("OPENAI_API_KEY"))
        #expect(output.allSatisfy { !$0.contains("must-not-be-read") })
    }

    @Test func resolvesExecutableBeforeReadingCredentials() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "OPENAI_API_KEY")],
            values: ["OPENAI_API_KEY": "keychain-value"]
        )
        let application = makeApplication(store: store, environment: ["PATH": "/usr/bin:/bin"])

        #expect(throws: PathResolutionError.self) {
            try application.prepareRun(program: "definitely-missing", arguments: [])
        }
        #expect(store.loadAllCallCount == 0)
    }

    @Test func preparesExactDirectExecutionPlan() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "GITHUB_TOKEN")],
            values: ["GITHUB_TOKEN": "keychain-value"]
        )
        let application = makeApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin", "GITHUB_TOKEN": "wrong"]
        )

        let plan = try application.prepareRun(program: "true", arguments: ["literal value"])
        #expect(plan.executable == "/usr/bin/true")
        #expect(plan.arguments == ["true", "literal value"])
        #expect(plan.environment["GITHUB_TOKEN"] == "keychain-value")
        #expect(store.loadAllCallCount == 1)
    }

    private func makeApplication(
        store: RecordingSecretStore,
        environment: [String: String]
    ) -> CLIApplication {
        CLIApplication(
            store: store,
            environment: environment,
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring"),
                linkURL: URL(fileURLWithPath: "/tmp/missing-agent-keyring")
            ),
            identityProvider: { "identifier test" },
            stdout: { _ in },
            stderr: { _ in }
        )
    }
}

private final class RecordingSecretStore: SecretStore {
    let names: [CredentialName]
    let values: [String: String]
    var loadAllCallCount = 0

    init(names: [CredentialName], values: [String: String]) {
        self.names = names
        self.values = values
    }

    func listNames() throws -> [CredentialName] { names }
    func save(name: CredentialName, value: String) throws {}
    func delete(name: CredentialName) throws {}
    func loadAll() throws -> [String: String] {
        loadAllCallCount += 1
        return values
    }
}
