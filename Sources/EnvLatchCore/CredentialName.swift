import Foundation

public enum CredentialValidationError: Error, Equatable, LocalizedError, Sendable {
    case invalidNameFormat
    case unsafeName
    case unsupportedCredentialName
    case emptyValue
    case valueContainsNul

    public var errorDescription: String? {
        switch self {
        case .invalidNameFormat:
            "Use uppercase letters, numbers, and underscores, starting with a letter or underscore."
        case .unsafeName:
            "Loader-control environment names are not allowed."
        case .unsupportedCredentialName:
            "Use a credential name ending in API_KEY, TOKEN, SECRET, PASSWORD, ACCESS_KEY, PRIVATE_KEY, or CREDENTIAL."
        case .emptyValue:
            "Enter a value before saving."
        case .valueContainsNul:
            "Credential values cannot contain a NUL character."
        }
    }
}

public struct CredentialName: Hashable, Comparable, Sendable {
    public let rawValue: String

    private static let allowedSuffixes = [
        "_API_KEY",
        "_TOKEN",
        "_SECRET",
        "_PASSWORD",
        "_ACCESS_KEY",
        "_PRIVATE_KEY",
        "_CREDENTIAL",
    ]

    public init(validating rawValue: String) throws {
        guard Self.hasValidPOSIXShape(rawValue) else {
            throw CredentialValidationError.invalidNameFormat
        }
        guard !rawValue.hasPrefix("DYLD_"), !rawValue.hasPrefix("LD_") else {
            throw CredentialValidationError.unsafeName
        }
        guard Self.allowedSuffixes.contains(where: rawValue.hasSuffix) else {
            throw CredentialValidationError.unsupportedCredentialName
        }
        self.rawValue = rawValue
    }

    public static func validateValue(_ value: String) throws {
        guard !value.isEmpty else {
            throw CredentialValidationError.emptyValue
        }
        guard !value.utf8.contains(0) else {
            throw CredentialValidationError.valueContainsNul
        }
    }

    public static func < (lhs: CredentialName, rhs: CredentialName) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func hasValidPOSIXShape(_ value: String) -> Bool {
        guard let first = value.utf8.first, isUppercaseLetter(first) || first == 95 else {
            return false
        }

        return value.utf8.dropFirst().allSatisfy {
            isUppercaseLetter($0) || (48...57).contains($0) || $0 == 95
        }
    }

    private static func isUppercaseLetter(_ byte: UInt8) -> Bool {
        (65...90).contains(byte)
    }
}
