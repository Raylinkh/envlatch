#if DEBUG
import EnvLatchCore
import Foundation

@MainActor
enum PreviewData {
    static let model: VaultViewModel = makeModel()

    private static func makeModel() -> VaultViewModel {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "envlatch-ui-preview-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        let endpointStore = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json"))
        let groupStore = LaunchProfileStore(fileURL: root.appendingPathComponent("groups.json"))

        let names = [
            try? CredentialName(validating: "OPENAI_API_KEY"),
            try? CredentialName(validating: "ANTHROPIC_API_KEY"),
            try? CredentialName(validating: "OPENROUTER_API_KEY"),
            try? CredentialName(validating: "GITHUB_TOKEN"),
        ].compactMap { $0 }

        if names.count == 4 {
            try? endpointStore.upsert(
                EndpointProfile(
                    providerName: "OpenAI",
                    credentialName: names[0],
                    contract: .openAIResponses,
                    baseURL: "https://api.openai.com/v1",
                    credentialEnvironmentName: names[0]
                )
            )
            try? endpointStore.upsert(
                EndpointProfile(
                    providerName: "Anthropic",
                    credentialName: names[1],
                    contract: .anthropic,
                    baseURL: "https://api.anthropic.com",
                    credentialEnvironmentName: names[1]
                )
            )
            try? endpointStore.upsert(
                EndpointProfile(
                    providerName: "OpenRouter",
                    credentialName: names[2],
                    contract: .openAIChat,
                    baseURL: "https://openrouter.ai/api/v1",
                    credentialEnvironmentName: CredentialName(validating: "OPENAI_API_KEY")
                )
            )
            try? groupStore.upsert(
                LaunchProfile(
                    name: "Backend",
                    credentialNames: [names[0], names[3]]
                )
            )
        }

        return VaultViewModel(
            store: PreviewSecretStore(names: names),
            profileStore: endpointStore,
            launchProfileStore: groupStore
        )
    }
}

private struct PreviewSecretStore: SecretStore {
    let names: [CredentialName]

    func listNames() throws -> [CredentialName] { names }
    func save(name: CredentialName, value: String) throws {}
    func delete(name: CredentialName) throws {}
    func load(name: CredentialName) throws -> String { "" }
    func loadAll() throws -> [String: String] { [:] }
}
#endif
