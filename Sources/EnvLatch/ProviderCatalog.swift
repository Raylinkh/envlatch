import EnvLatchCore
import Foundation

struct ProviderPreset: Identifiable, Equatable {
    let id: String
    let displayName: String
    let suggestedCredentialName: String
    let contract: APIContract
    let baseURL: String
    let exposedCredentialName: String

    func endpointProfile(for credential: CredentialName) throws -> EndpointProfile? {
        try EndpointProfile(
            providerName: displayName,
            credentialName: credential,
            contract: contract,
            baseURL: baseURL,
            credentialEnvironmentName: CredentialName(validating: exposedCredentialName)
        )
    }

    static func matching(
        credential: CredentialName,
        endpoint: EndpointProfile?
    ) -> ProviderPreset? {
        guard let endpoint else { return nil }
        return catalog.first {
            $0.displayName.caseInsensitiveCompare(endpoint.providerName) == .orderedSame
                && $0.contract == endpoint.contract
                && $0.baseURL == endpoint.baseURL
                && $0.exposedCredentialName == endpoint.credentialEnvironmentName.rawValue
        }
    }

    static let catalog: [ProviderPreset] = [
        ProviderPreset(
            id: "openai",
            displayName: "OpenAI",
            suggestedCredentialName: "OPENAI_API_KEY",
            contract: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            exposedCredentialName: "OPENAI_API_KEY"
        ),
        ProviderPreset(
            id: "anthropic",
            displayName: "Anthropic",
            suggestedCredentialName: "ANTHROPIC_API_KEY",
            contract: .anthropic,
            baseURL: "https://api.anthropic.com",
            exposedCredentialName: "ANTHROPIC_API_KEY"
        ),
        ProviderPreset(
            id: "gemini",
            displayName: "Gemini",
            suggestedCredentialName: "GEMINI_API_KEY",
            contract: .gemini,
            baseURL: "https://generativelanguage.googleapis.com",
            exposedCredentialName: "GEMINI_API_KEY"
        ),
        ProviderPreset(
            id: "openrouter",
            displayName: "OpenRouter",
            suggestedCredentialName: "OPENROUTER_API_KEY",
            contract: .openAIChat,
            baseURL: "https://openrouter.ai/api/v1",
            exposedCredentialName: "OPENAI_API_KEY"
        ),
        ProviderPreset(
            id: "minimax",
            displayName: "MiniMax",
            suggestedCredentialName: "MINIMAX_API_KEY",
            contract: .anthropic,
            baseURL: "https://api.minimaxi.com/anthropic",
            exposedCredentialName: "ANTHROPIC_AUTH_TOKEN"
        ),
    ]
}
