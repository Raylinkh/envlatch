import Foundation

public enum APIContract: String, CaseIterable, Codable, Equatable, Sendable {
    case anthropic
    case openAIChat = "openai-chat"
    case openAIResponses = "openai-responses"
    case gemini

    public var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAIChat: "OpenAI Chat Completions"
        case .openAIResponses: "OpenAI Responses"
        case .gemini: "Gemini"
        }
    }

    public var defaultCredentialEnvironmentName: String {
        switch self {
        case .anthropic: "ANTHROPIC_AUTH_TOKEN"
        case .openAIChat, .openAIResponses: "OPENAI_API_KEY"
        case .gemini: "GEMINI_API_KEY"
        }
    }

    public var baseURLEnvironmentName: String {
        switch self {
        case .anthropic: "ANTHROPIC_BASE_URL"
        case .openAIChat, .openAIResponses: "OPENAI_BASE_URL"
        case .gemini: "GOOGLE_GEMINI_BASE_URL"
        }
    }
}

public enum EndpointProfileError: Error, Equatable, LocalizedError, Sendable {
    case invalidProviderName
    case invalidBaseURL
    case profileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProviderName:
            "Use a provider/profile name between 1 and 80 characters with no control characters."
        case .invalidBaseURL:
            "Use an http or https base URL with no embedded username or password."
        case .profileNotFound(let identifier):
            "No endpoint profile matches \(identifier). Run `agent-keyring profiles` to list available profiles."
        }
    }
}

public struct EndpointProfile: Codable, Equatable, Identifiable, Sendable {
    public let providerName: String
    public let credentialName: CredentialName
    public let contract: APIContract
    public let baseURL: String
    public let credentialEnvironmentName: CredentialName

    public var id: String { credentialName.rawValue }

    public init(
        providerName rawProviderName: String,
        credentialName: CredentialName,
        contract: APIContract,
        baseURL rawBaseURL: String,
        credentialEnvironmentName: CredentialName? = nil
    ) throws {
        let providerName = rawProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerName.isEmpty,
              providerName.count <= 80,
              providerName.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw EndpointProfileError.invalidProviderName
        }

        let baseURL = rawBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: baseURL),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil,
              components.user == nil,
              components.password == nil else {
            throw EndpointProfileError.invalidBaseURL
        }

        self.providerName = providerName
        self.credentialName = credentialName
        self.contract = contract
        self.baseURL = baseURL
        self.credentialEnvironmentName = try credentialEnvironmentName
            ?? CredentialName(validating: contract.defaultCredentialEnvironmentName)
    }

    public var secretEnvironmentNames: [String] {
        if credentialEnvironmentName == credentialName {
            return [credentialName.rawValue]
        }
        return [credentialName.rawValue, credentialEnvironmentName.rawValue]
    }

    public var configurationEnvironment: [String: String] {
        [contract.baseURLEnvironmentName: baseURL]
    }

    private enum CodingKeys: String, CodingKey {
        case providerName
        case credentialName
        case contract
        case baseURL
        case credentialEnvironmentName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            providerName: container.decode(String.self, forKey: .providerName),
            credentialName: CredentialName(
                validating: container.decode(String.self, forKey: .credentialName)
            ),
            contract: container.decode(APIContract.self, forKey: .contract),
            baseURL: container.decode(String.self, forKey: .baseURL),
            credentialEnvironmentName: CredentialName(
                validating: container.decode(String.self, forKey: .credentialEnvironmentName)
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerName, forKey: .providerName)
        try container.encode(credentialName.rawValue, forKey: .credentialName)
        try container.encode(contract, forKey: .contract)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(credentialEnvironmentName.rawValue, forKey: .credentialEnvironmentName)
    }
}
