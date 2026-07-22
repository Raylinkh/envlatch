import Foundation

public enum CLICommand: Equatable, Sendable {
    case list
    case profiles
    case doctor
    case pair(name: String)
    case run(profile: String?, program: String, arguments: [String])
    case help
}

public enum CLIParseError: Error, Equatable, LocalizedError, Sendable {
    case missingCommand
    case unknownCommand(String)
    case unexpectedArguments(String)
    case missingPairName
    case missingProfile
    case missingRunSeparator
    case missingProgram

    public var errorDescription: String? {
        switch self {
        case .missingCommand:
            "Choose pair, list, doctor, run, or help."
        case .unknownCommand(let command):
            "Unknown command: \(command)"
        case .unexpectedArguments(let command):
            "The \(command) command does not accept arguments."
        case .missingPairName:
            "Use `agent-keyring pair <agent-or-host-name>`."
        case .missingProfile:
            "Use `agent-keyring run --using <profile-name> -- <program> [args...]`."
        case .missingRunSeparator:
            "Use `agent-keyring run -- <program> [args...]`."
        case .missingProgram:
            "Provide a program after `run --`."
        }
    }
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else {
            throw CLIParseError.missingCommand
        }

        switch command {
        case "list":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .list
        case "profiles":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .profiles
        case "doctor":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .doctor
        case "pair":
            guard arguments.count >= 2 else {
                throw CLIParseError.missingPairName
            }
            return .pair(name: arguments.dropFirst().joined(separator: " "))
        case "run":
            if arguments.count >= 2, arguments[1] == "--" {
                guard arguments.count >= 3 else {
                    throw CLIParseError.missingProgram
                }
                return .run(profile: nil, program: arguments[2], arguments: Array(arguments.dropFirst(3)))
            }
            guard arguments.count >= 2, arguments[1] == "--using" else {
                throw CLIParseError.missingRunSeparator
            }
            guard let separatorIndex = arguments.dropFirst(2).firstIndex(of: "--"), separatorIndex > 2 else {
                throw CLIParseError.missingProfile
            }
            guard arguments.index(after: separatorIndex) < arguments.endIndex else {
                throw CLIParseError.missingProgram
            }
            let profile = arguments[2..<separatorIndex].joined(separator: " ")
            let programIndex = arguments.index(after: separatorIndex)
            return .run(
                profile: profile,
                program: arguments[programIndex],
                arguments: Array(arguments.dropFirst(programIndex + 1))
            )
        case "help", "--help", "-h":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .help
        default:
            throw CLIParseError.unknownCommand(command)
        }
    }
}
