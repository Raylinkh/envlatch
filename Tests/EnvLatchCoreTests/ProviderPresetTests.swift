import Testing
@testable import EnvLatch
@testable import EnvLatchCore

@Suite("Provider-aware key setup")
struct ProviderPresetTests {
    @Test func catalogHasUniqueValidDefaults() throws {
        let presets = ProviderPreset.catalog

        #expect(presets.count == 5)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(Set(presets.map(\.suggestedCredentialName)).count == presets.count)

        for preset in presets {
            let credential = try CredentialName(validating: preset.suggestedCredentialName)
            let storedEndpoint = try preset.endpointProfile(for: credential)
            let endpoint = try #require(storedEndpoint)

            #expect(endpoint.providerName == preset.displayName)
            #expect(endpoint.credentialName == credential)
            #expect(endpoint.contract == preset.contract)
            #expect(endpoint.baseURL == preset.baseURL)
            #expect(endpoint.credentialEnvironmentName.rawValue == preset.exposedCredentialName)
        }
    }

    @Test func miniMaxPresetMatchesTheDocumentedAnthropicBinding() throws {
        let preset = try #require(ProviderPreset.catalog.first { $0.id == "minimax" })
        let credential = try CredentialName(validating: preset.suggestedCredentialName)
        let storedEndpoint = try preset.endpointProfile(for: credential)
        let endpoint = try #require(storedEndpoint)

        #expect(endpoint.contract == .anthropic)
        #expect(endpoint.baseURL == "https://api.minimaxi.com/anthropic")
        #expect(endpoint.credentialEnvironmentName.rawValue == "ANTHROPIC_AUTH_TOKEN")
    }

    @Test func existingEndpointSelectsItsProviderPreset() throws {
        let credential = try CredentialName(validating: "ROUTER_TOKEN")
        let endpoint = try EndpointProfile(
            providerName: "OpenRouter",
            credentialName: credential,
            contract: .openAIChat,
            baseURL: "https://openrouter.ai/api/v1",
            credentialEnvironmentName: CredentialName(validating: "OPENAI_API_KEY")
        )

        #expect(ProviderPreset.matching(credential: credential, endpoint: endpoint)?.id == "openrouter")
        #expect(ProviderPreset.matching(credential: credential, endpoint: nil) == nil)
    }

    @Test func everyPresetHasABundledProviderLogo() throws {
        for preset in ProviderPreset.catalog {
            let presentation = ProviderPresentation.presentation(for: preset)
            let assetName = try #require(presentation.iconAssetName)

            #expect(ProviderIconAsset.url(named: assetName) != nil)
        }
    }

    @Test func commonDirectKeysUseRecognizableProviderLogos() throws {
        let github = try CredentialName(validating: "GITHUB_TOKEN")
        let aws = try CredentialName(validating: "AWS_SECRET_ACCESS_KEY")

        #expect(
            ProviderPresentation.resolve(credential: github, endpoint: nil).iconAssetName
                == "github"
        )
        #expect(
            ProviderPresentation.resolve(credential: aws, endpoint: nil).iconAssetName
                == "aws-color"
        )
    }
}
