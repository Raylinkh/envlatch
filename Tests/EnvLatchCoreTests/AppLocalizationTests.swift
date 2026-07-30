import Foundation
import Testing
@testable import EnvLatch
@testable import EnvLatchCore

@Suite("Simplified Chinese app localization")
struct AppLocalizationTests {
    private let english = Locale(identifier: "en")
    private let simplifiedChinese = Locale(identifier: "zh-Hans")

    @Test func criticalWorkflowCopyResolvesInBothLanguages() {
        #expect(
            AppLocalization.text(
                "vault.header.tagline",
                "One Keychain for every local agent",
                locale: english
            ) == "One Keychain for every local agent"
        )
        #expect(
            AppLocalization.text(
                "vault.header.tagline",
                "One Keychain for every local agent",
                locale: simplifiedChinese
            ) == "一个钥匙串，供所有本地智能体使用"
        )
        #expect(
            AppLocalization.text(
                "vault.action.addKey",
                "Add Key",
                locale: simplifiedChinese
            ) == "添加密钥"
        )
        #expect(
            AppLocalization.text(
                "vault.agentSetup.needsRepair",
                "Shared setup needs repair",
                locale: simplifiedChinese
            ) == "共享设置需要修复"
        )
    }

    @Test func everyUsedKeyHasAChineseCatalogTranslationAndRuntimeMirror() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = root
            .appendingPathComponent("Sources/EnvLatch/Resources/Localizable.xcstrings")
        let mirrorURL = root
            .appendingPathComponent(
                "Sources/EnvLatch/Resources/zh-Hans.lproj/Localizable.strings"
            )

        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try #require(
            JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )
        let catalogStrings = try #require(catalog["strings"] as? [String: Any])
        let catalogTranslations = try Dictionary(
            uniqueKeysWithValues: catalogStrings.map { key, rawEntry in
                let entry = try #require(rawEntry as? [String: Any])
                let localizations = try #require(
                    entry["localizations"] as? [String: Any]
                )
                let chinese = try #require(localizations["zh-Hans"] as? [String: Any])
                let unit = try #require(chinese["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                return (key, value)
            }
        )
        let runtimeTranslations = try #require(
            NSDictionary(contentsOf: mirrorURL) as? [String: String]
        )

        #expect(catalogTranslations == runtimeTranslations)
        #expect(try usedLocalizationKeys(root: root).isSubset(of: catalogTranslations.keys))
    }

    @Test func dynamicCountsAndValidationMessagesKeepTheirValues() {
        #expect(
            AppLocalization.keyCount(4, locale: simplifiedChinese)
                == "4 个密钥"
        )
        #expect(
            AppLocalization.groupCount(1, locale: english)
                == "1 group"
        )
        #expect(
            AppLocalization.text(
                "status.key.saved",
                "Saved \("OPENAI_API_KEY") in Keychain.",
                locale: simplifiedChinese
            ) == "已将 OPENAI_API_KEY 存入钥匙串。"
        )
        #expect(
            AppLocalization.message(
                for: CredentialValidationError.invalidNameFormat,
                locale: simplifiedChinese
            ) == "请使用大写字母、数字和下划线，并以字母或下划线开头。"
        )
    }

    private func usedLocalizationKeys(root: URL) throws -> Set<String> {
        let sourceURLs = [
            root.appendingPathComponent("Sources/EnvLatch/AppLocalization.swift"),
            root.appendingPathComponent("Sources/EnvLatch/AppSettings.swift"),
            root.appendingPathComponent("Sources/EnvLatch/VaultView.swift"),
            root.appendingPathComponent("Sources/EnvLatch/VaultViewModel.swift"),
        ]
        let regex = try NSRegularExpression(
            pattern: #"(?:AppLocalization\.)?text\(\s*"([^"]+)""#
        )
        var keys: Set<String> = []

        for url in sourceURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in regex.matches(in: source, range: range) {
                guard
                    let keyRange = Range(match.range(at: 1), in: source)
                else {
                    continue
                }
                keys.insert(String(source[keyRange]))
            }
        }
        return keys
    }
}
