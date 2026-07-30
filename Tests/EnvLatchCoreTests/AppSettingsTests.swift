import Foundation
import Testing

@testable import EnvLatch

@Suite("Native app settings")
struct AppSettingsTests {
    @Test func languagePreferenceSupportsSystemEnglishAndSimplifiedChinese() {
        #expect(AppLanguage(rawValue: "system") == .system)
        #expect(AppLanguage(rawValue: "en") == .english)
        #expect(AppLanguage(rawValue: "zh-Hans") == .simplifiedChinese)
        #expect(AppLanguage(rawValue: "unsupported") == nil)

        #expect(AppLanguage.english.locale.identifier == "en")
        #expect(AppLanguage.simplifiedChinese.locale.identifier == "zh-Hans")
    }

    @Test func aboutInfoShowsVersionBuildAndInstallationKind() {
        let installed = AppAboutInfo(
            version: "0.3.0",
            build: "5",
            bundleURL: URL(fileURLWithPath: "/Users/test/Applications/EnvLatch.app")
        )
        let development = AppAboutInfo(
            version: "0.3.0",
            build: "5",
            bundleURL: URL(
                fileURLWithPath: "/Users/test/Documents/projects/EnvLatch/dist/EnvLatch.app"
            )
        )

        #expect(installed.versionText == "0.3.0 (5)")
        #expect(installed.installationKind == .installed)
        #expect(development.installationKind == .development)
    }
}
