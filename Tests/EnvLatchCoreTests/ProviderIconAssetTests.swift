import Foundation
import Testing

@testable import EnvLatch

@Suite("Provider icon resources")
struct ProviderIconAssetTests {
    @Test func swiftPMIconsAreAvailable() {
        #expect(ProviderIconAsset.url(named: "openai") != nil)
        #expect(ProviderIconAsset.url(named: "gemini-raster") != nil)
    }

    @Test func relocatedAppSupportsLegacyResourcesAndMissingIcons() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("EnvLatch.app")
        let resources = app.appendingPathComponent("Contents/Resources")
        let icons = resources.appendingPathComponent("ProviderIcons")
        try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "dev.envlatch.icon-tests",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "EnvLatch",
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let icon = icons.appendingPathComponent("openai.svg")
        try Data("<svg/>".utf8).write(to: icon)
        let bundle = try #require(Bundle(url: app))
        #expect(ProviderIconAsset.url(named: "openai", mainBundle: bundle) == icon)
        #expect(ProviderIconAsset.url(named: "missing", mainBundle: bundle) == nil)

        // New app packages keep the SwiftPM bundle inside Resources.
        try FileManager.default.removeItem(at: icons)
        let nested = resources.appendingPathComponent("EnvLatch_EnvLatch.bundle")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": "dev.envlatch.icon-tests.resources"],
            format: .xml,
            options: 0
        ).write(to: nested.appendingPathComponent("Info.plist"))
        let nestedIcon = nested.appendingPathComponent("gemini-raster.png")
        try Data().write(to: nestedIcon)
        #expect(ProviderIconAsset.url(named: "gemini-raster", mainBundle: bundle) == nestedIcon)
    }
}
