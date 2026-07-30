import AppKit
import EnvLatchCore
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            Locale(
                identifier: Bundle.main.preferredLocalizations.first
                    ?? Locale.preferredLanguages.first
                    ?? "en"
            )
        case .english, .simplifiedChinese:
            Locale(identifier: rawValue)
        }
    }

    static var current: AppLanguage {
        guard
            let rawValue = UserDefaults.standard.string(forKey: storageKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .system
        }
        return language
    }
}

enum AppInstallationKind: Equatable {
    case installed
    case development
    case other
}

struct AppAboutInfo: Equatable {
    let version: String
    let build: String
    let bundleURL: URL

    static var current: AppAboutInfo {
        let info = Bundle.main.infoDictionary
        return AppAboutInfo(
            version: info?["CFBundleShortVersionString"] as? String
                ?? ProductInfo.version,
            build: info?["CFBundleVersion"] as? String ?? "",
            bundleURL: Bundle.main.bundleURL
        )
    }

    var versionText: String {
        build.isEmpty ? version : "\(version) (\(build))"
    }

    var installationKind: AppInstallationKind {
        let path = bundleURL.standardizedFileURL.path
        if path.contains("/Applications/") {
            return .installed
        }
        if path.contains("/dist/") || bundleURL.pathExtension != "app" {
            return .development
        }
        return .other
    }

    var displayPath: String {
        let path = bundleURL.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix("\(home)/") else {
            return path
        }
        return "~" + path.dropFirst(home.count)
    }
}

struct AppSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue

    private let aboutInfo: AppAboutInfo

    init(aboutInfo: AppAboutInfo = .current) {
        self.aboutInfo = aboutInfo
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(
                    AppLocalization.text("settings.language.label", "Language")
                ) {
                    Picker("", selection: $language) {
                        Text(
                            AppLocalization.text(
                                "settings.language.system",
                                "System Default"
                            )
                        )
                        .tag(AppLanguage.system.rawValue)
                        Text("English")
                            .tag(AppLanguage.english.rawValue)
                        Text("简体中文")
                            .tag(AppLanguage.simplifiedChinese.rawValue)
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                Text(
                    AppLocalization.text(
                        "settings.language.detail",
                        "Changes apply immediately. System menus continue to follow macOS."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text(AppLocalization.text("settings.general.title", "General"))
            }

            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("EnvLatch")
                            .font(.headline)
                        Text(
                            "\(AppLocalization.text("settings.about.version", "Version")) \(aboutInfo.versionText)"
                        )
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)

                LabeledContent(
                    AppLocalization.text("settings.about.location", "Location")
                ) {
                    Label(
                        installationLabel,
                        systemImage: installationSystemImage
                    )
                    .foregroundStyle(installationColor)
                }

                Text(aboutInfo.displayPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Button(
                    AppLocalization.text(
                        "settings.about.showInFinder",
                        "Show in Finder"
                    )
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([aboutInfo.bundleURL])
                }
            } header: {
                Text(AppLocalization.text("settings.about.title", "About"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
    }

    private var installationLabel: String {
        switch aboutInfo.installationKind {
        case .installed:
            AppLocalization.text(
                "settings.about.installed",
                "Installed app"
            )
        case .development:
            AppLocalization.text(
                "settings.about.development",
                "Development build"
            )
        case .other:
            AppLocalization.text(
                "settings.about.other",
                "App bundle"
            )
        }
    }

    private var installationSystemImage: String {
        switch aboutInfo.installationKind {
        case .installed:
            "checkmark.circle.fill"
        case .development:
            "hammer.fill"
        case .other:
            "app.fill"
        }
    }

    private var installationColor: Color {
        switch aboutInfo.installationKind {
        case .installed:
            .green
        case .development, .other:
            .secondary
        }
    }
}
