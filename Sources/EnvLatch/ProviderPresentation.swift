import AppKit
import EnvLatchCore
import SwiftUI

struct ProviderPresentation {
    let name: String
    let iconAssetName: String?
    let usesOriginalIconColor: Bool
    let fallbackSymbolName: String
    let color: Color

    static func resolve(
        credential: CredentialName,
        endpoint: EndpointProfile?
    ) -> ProviderPresentation {
        if let preset = ProviderPreset.matching(credential: credential, endpoint: endpoint) {
            return presentation(for: preset)
        }

        let searchable = [
            credential.rawValue,
            endpoint?.providerName ?? "",
        ].joined(separator: " ").uppercased()

        if searchable.contains("OPENAI") {
            return provider(
                name: endpoint?.providerName ?? "OpenAI",
                iconAssetName: "openai",
                fallbackSymbolName: "circle.hexagongrid.fill",
                color: .mint
            )
        }
        if searchable.contains("ANTHROPIC") || searchable.contains("CLAUDE") {
            return provider(
                name: endpoint?.providerName ?? "Anthropic",
                iconAssetName: "anthropic",
                fallbackSymbolName: "textformat",
                color: .orange
            )
        }
        if searchable.contains("GEMINI") || searchable.contains("GOOGLE") {
            return provider(
                name: endpoint?.providerName ?? "Gemini",
                iconAssetName: "gemini-raster",
                fallbackSymbolName: "sparkles",
                color: .blue
            )
        }
        if searchable.contains("OPENROUTER") {
            return provider(
                name: endpoint?.providerName ?? "OpenRouter",
                iconAssetName: "openrouter-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "arrow.triangle.branch",
                color: .purple
            )
        }
        if searchable.contains("MINIMAX") {
            return provider(
                name: endpoint?.providerName ?? "MiniMax",
                iconAssetName: "minimax-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "waveform.path.ecg",
                color: .indigo
            )
        }
        if searchable.contains("GITHUB") {
            return provider(
                name: endpoint?.providerName ?? "GitHub",
                iconAssetName: "github",
                fallbackSymbolName: "chevron.left.forwardslash.chevron.right",
                color: .secondary
            )
        }
        if searchable.contains("AWS") {
            return provider(
                name: endpoint?.providerName ?? "AWS",
                iconAssetName: "aws-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "cloud.fill",
                color: .orange
            )
        }
        if searchable.contains("GROQ") {
            return provider(
                name: endpoint?.providerName ?? "Groq",
                iconAssetName: "groq",
                fallbackSymbolName: "bolt.fill",
                color: .orange
            )
        }
        if searchable.contains("MISTRAL") {
            return provider(
                name: endpoint?.providerName ?? "Mistral",
                iconAssetName: "mistral-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "wind",
                color: .blue
            )
        }
        if searchable.contains("XAI") {
            return provider(
                name: endpoint?.providerName ?? "xAI",
                iconAssetName: "xai",
                fallbackSymbolName: "xmark.circle.fill",
                color: .secondary
            )
        }
        if searchable.contains("COHERE") {
            return provider(
                name: endpoint?.providerName ?? "Cohere",
                iconAssetName: "cohere-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "circle.grid.2x2.fill",
                color: .mint
            )
        }
        if searchable.contains("FISH_AUDIO") {
            return provider(
                name: endpoint?.providerName ?? "Fish Audio",
                iconAssetName: "fishaudio",
                fallbackSymbolName: "waveform",
                color: .cyan
            )
        }
        if searchable.contains("APPLE_TEAM") {
            return provider(
                name: endpoint?.providerName ?? "Apple Developer",
                iconAssetName: "apple",
                fallbackSymbolName: "signature",
                color: .secondary
            )
        }

        return provider(
            name: endpoint?.providerName ?? "Custom",
            fallbackSymbolName: "key.fill",
            color: .accentColor
        )
    }

    static func presentation(for preset: ProviderPreset) -> ProviderPresentation {
        switch preset.id {
        case "openai":
            provider(
                name: preset.displayName,
                iconAssetName: "openai",
                fallbackSymbolName: "circle.hexagongrid.fill",
                color: .mint
            )
        case "anthropic":
            provider(
                name: preset.displayName,
                iconAssetName: "anthropic",
                fallbackSymbolName: "textformat",
                color: .orange
            )
        case "gemini":
            provider(
                name: preset.displayName,
                iconAssetName: "gemini-raster",
                fallbackSymbolName: "sparkles",
                color: .blue
            )
        case "openrouter":
            provider(
                name: preset.displayName,
                iconAssetName: "openrouter-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "arrow.triangle.branch",
                color: .purple
            )
        case "minimax":
            provider(
                name: preset.displayName,
                iconAssetName: "minimax-color",
                usesOriginalIconColor: true,
                fallbackSymbolName: "waveform.path.ecg",
                color: .indigo
            )
        default:
            provider(
                name: preset.displayName,
                fallbackSymbolName: "key.fill",
                color: .accentColor
            )
        }
    }

    private static func provider(
        name: String,
        iconAssetName: String? = nil,
        usesOriginalIconColor: Bool = false,
        fallbackSymbolName: String,
        color: Color
    ) -> ProviderPresentation {
        ProviderPresentation(
            name: name,
            iconAssetName: iconAssetName,
            usesOriginalIconColor: usesOriginalIconColor,
            fallbackSymbolName: fallbackSymbolName,
            color: color
        )
    }
}

enum ProviderIconAsset {
    static func url(named name: String) -> URL? {
        for fileExtension in ["svg", "png"] {
            for bundle in [Bundle.main, Bundle.module] {
                if let url = bundle.url(
                    forResource: name,
                    withExtension: fileExtension,
                    subdirectory: "ProviderIcons"
                ) ?? bundle.url(forResource: name, withExtension: fileExtension) {
                    return url
                }
            }
        }
        return nil
    }

    static func image(named name: String, usesOriginalColor: Bool) -> NSImage? {
        guard
            let url = url(named: name),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = !usesOriginalColor
        return image
    }
}

struct ProviderMark: View {
    let presentation: ProviderPresentation
    var size: CGFloat = 40

    var body: some View {
        Group {
            if
                let iconAssetName = presentation.iconAssetName,
                let icon = ProviderIconAsset.image(
                    named: iconAssetName,
                    usesOriginalColor: presentation.usesOriginalIconColor
                )
            {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(presentation.usesOriginalIconColor ? .original : .template)
                    .scaledToFit()
                    .foregroundStyle(presentation.color)
                    .padding(size * 0.22)
            } else {
                Image(systemName: presentation.fallbackSymbolName)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(presentation.color)
            }
        }
        .frame(width: size, height: size)
        .background(presentation.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
