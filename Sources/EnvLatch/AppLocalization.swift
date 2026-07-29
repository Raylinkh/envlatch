import EnvLatchCore
import Foundation
import Security

enum AppLocalization {
    static var bundle: Bundle {
        if Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: "zh-Hans"
        ) != nil {
            return .main
        }
        return .module
    }

    static func text(
        _ key: StaticString,
        _ defaultValue: String.LocalizationValue,
        locale: Locale? = nil
    ) -> String {
        let locale = locale
            ?? previewLocale
            ?? Locale(identifier: bundle.preferredLocalizations.first ?? "en")
        return String(
            localized: key,
            defaultValue: defaultValue,
            table: "Localizable",
            bundle: localizedBundle(for: locale),
            locale: locale
        )
    }

    static func keyCount(_ count: Int, locale: Locale? = nil) -> String {
        count == 1
            ? text("count.key.one", "\(count) key", locale: locale)
            : text("count.key.other", "\(count) keys", locale: locale)
    }

    static func groupCount(_ count: Int, locale: Locale? = nil) -> String {
        count == 1
            ? text("count.group.one", "\(count) group", locale: locale)
            : text("count.group.other", "\(count) groups", locale: locale)
    }

    static func matchingCount(_ count: Int, locale: Locale? = nil) -> String {
        text("count.matching", "\(count) matching", locale: locale)
    }

    static func pairedHostCount(_ count: Int, locale: Locale? = nil) -> String {
        count == 1
            ? text("count.pairedHost.one", "\(count) named host paired", locale: locale)
            : text("count.pairedHost.other", "\(count) named hosts paired", locale: locale)
    }

    static func message(for error: Error, locale: Locale? = nil) -> String {
        switch error {
        case let error as CredentialValidationError:
            switch error {
            case .invalidNameFormat:
                text(
                    "error.credential.invalidNameFormat",
                    "Use uppercase letters, numbers, and underscores, starting with a letter or underscore.",
                    locale: locale
                )
            case .unsafeName:
                text(
                    "error.credential.unsafeName",
                    "Loader-control environment names are not allowed.",
                    locale: locale
                )
            case .unsupportedCredentialName:
                text(
                    "error.credential.unsupportedName",
                    "Use a credential name ending in API_KEY, TOKEN, SECRET, PASSWORD, ACCESS_KEY, PRIVATE_KEY, or CREDENTIAL.",
                    locale: locale
                )
            case .emptyValue:
                text("error.credential.emptyValue", "Enter a value before saving.", locale: locale)
            case .valueContainsNul:
                text(
                    "error.credential.valueContainsNul",
                    "Credential values cannot contain a NUL character.",
                    locale: locale
                )
            }
        case let error as EndpointProfileError:
            switch error {
            case .invalidProviderName:
                text(
                    "error.endpoint.invalidProviderName",
                    "Use a provider/profile name between 1 and 80 characters with no control characters.",
                    locale: locale
                )
            case .invalidBaseURL:
                text(
                    "error.endpoint.invalidBaseURL",
                    "Use an https base URL, or http only for localhost/loopback, with no credentials, query, or fragment.",
                    locale: locale
                )
            }
        case let error as LaunchProfileError:
            launchProfileMessage(error, locale: locale)
        case let error as KeychainStoreError:
            keychainMessage(error, locale: locale)
        case let error as CredentialMutationError:
            switch error {
            case .rollbackFailed(let original, let rollback):
                text(
                    "error.mutation.rollbackFailed",
                    "The operation failed and EnvLatch could not restore the previous endpoint metadata. Original error: \(original). Rollback error: \(rollback).",
                    locale: locale
                )
            }
        case is PairedHostError:
            text(
                "error.pairedHost.invalidName",
                "Use a name between 1 and 80 characters with no line breaks or control characters.",
                locale: locale
            )
        default:
            error.localizedDescription
        }
    }

    private static func launchProfileMessage(
        _ error: LaunchProfileError,
        locale: Locale?
    ) -> String {
        switch error {
        case .invalidName:
            text(
                "error.group.invalidName",
                "Use a key-group name between 1 and 80 characters with no control characters.",
                locale: locale
            )
        case .emptyCredentials:
            text(
                "error.group.emptyCredentials",
                "Select at least one saved key for the key group.",
                locale: locale
            )
        case .duplicateCredential(let name):
            text(
                "error.group.duplicateCredential",
                "The key group contains \(name) more than once.",
                locale: locale
            )
        case .profileNotFound(let name):
            text(
                "error.group.notFound",
                "No saved key or key group is named \(name). Run `envlatch list` or `envlatch groups` to see available names.",
                locale: locale
            )
        case .profileAlreadyExists(let name):
            text(
                "error.group.alreadyExists",
                "Key group \(name) already exists. Edit it in the EnvLatch GUI or choose another name.",
                locale: locale
            )
        case .duplicateSelection(let name):
            text(
                "error.group.duplicateSelection",
                "The transient selection includes \(name) more than once.",
                locale: locale
            )
        case .groupCannotBeCombined(let name):
            text(
                "error.group.cannotCombine",
                "Key group \(name) must be used by itself. Repeat `--using` only with saved key names.",
                locale: locale
            )
        case .ambiguousSelection(let name):
            text(
                "error.group.ambiguousSelection",
                "A saved key and key group are both named \(name). Rename or delete the key group before launching.",
                locale: locale
            )
        case .missingCredential(let profile, let credential):
            text(
                "error.group.missingCredential",
                "Key group \(profile) references missing key \(credential). Edit the group before launching.",
                locale: locale
            )
        case .conflictingSecretEnvironment(let name, let first, let second):
            text(
                "error.group.conflictingSecretEnvironment",
                "Key group maps both \(first) and \(second) to \(name). Give each selected key a distinct target environment name.",
                locale: locale
            )
        case .conflictingConfigurationEnvironment(let name):
            text(
                "error.group.conflictingConfigurationEnvironment",
                "Key group contains conflicting values for \(name). Split those endpoints into separate groups.",
                locale: locale
            )
        case .credentialInUse(let credential, let profiles):
            text(
                "error.group.credentialInUse",
                "Remove \(credential) from key group(s) \(profiles.joined(separator: ", ")) before deleting it.",
                locale: locale
            )
        }
    }

    private static func keychainMessage(
        _ error: KeychainStoreError,
        locale: Locale?
    ) -> String {
        switch error {
        case .osStatus(_, let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String?
                ?? text("error.keychain.unknown", "Unknown Keychain error", locale: locale)
            return text(
                "error.keychain.osStatus",
                "Keychain operation failed (\(status)): \(systemMessage)",
                locale: locale
            )
        case .unexpectedResult:
            return text(
                "error.keychain.unexpectedResult",
                "Keychain returned an unexpected result.",
                locale: locale
            )
        case .invalidStoredName(let name):
            return text(
                "error.keychain.invalidStoredName",
                "Keychain contains an unsafe EnvLatch item named \(name). Remove it in Keychain Access.",
                locale: locale
            )
        case .invalidStoredValue(let name):
            return text(
                "error.keychain.invalidStoredValue",
                "Keychain contains an invalid value for \(name). Replace it in EnvLatch.",
                locale: locale
            )
        }
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        guard
            let stringsURL = bundle.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: locale.identifier
            ),
            let localizedBundle = Bundle(url: stringsURL.deletingLastPathComponent())
        else {
            return bundle
        }
        return localizedBundle
    }

    private static var previewLocale: Locale? {
#if DEBUG
        ProcessInfo.processInfo.environment["ENVLATCH_LOCALE_OVERRIDE"].map(Locale.init(identifier:))
#else
        nil
#endif
    }
}
