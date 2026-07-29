import AppKit
import Foundation
import SwiftUI
import Testing
@testable import EnvLatch

@Suite("Bilingual vault rendering", .serialized)
@MainActor
struct VaultLocalizationRenderTests {
    @Test func englishAndSimplifiedChineseRenderAtTheDefaultWindowSize() throws {
        let originalPreview = ProcessInfo.processInfo.environment["ENVLATCH_PREVIEW_DATA"]
        let originalLocale = ProcessInfo.processInfo.environment["ENVLATCH_LOCALE_OVERRIDE"]
        defer {
            restoreEnvironment("ENVLATCH_PREVIEW_DATA", value: originalPreview)
            restoreEnvironment("ENVLATCH_LOCALE_OVERRIDE", value: originalLocale)
        }

        setenv("ENVLATCH_PREVIEW_DATA", "1", 1)
        let outputDirectory = ProcessInfo.processInfo.environment[
            "ENVLATCH_RENDER_OUTPUT_DIR"
        ].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let outputDirectory {
            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true
            )
        }

        for localeIdentifier in ["en", "zh-Hans"] {
            setenv("ENVLATCH_LOCALE_OVERRIDE", localeIdentifier, 1)
            let renderer = ImageRenderer(
                content: VaultView(model: PreviewData.model)
                    .frame(width: 880, height: 700)
            )
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            #expect(image.size == NSSize(width: 880, height: 700))

            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            #expect(png.count > 20_000)

            if let outputDirectory {
                try png.write(
                    to: outputDirectory.appendingPathComponent(
                        "envlatch-\(localeIdentifier).png"
                    ),
                    options: .atomic
                )
            }
        }
    }

    private func restoreEnvironment(_ name: String, value: String?) {
        if let value {
            setenv(name, value, 1)
        } else {
            unsetenv(name)
        }
    }
}
