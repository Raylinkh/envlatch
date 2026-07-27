import Foundation

public enum CLICommand: Equatable, Sendable {
    case list
    case profiles
    case createGroup(name: String, credentialNames: [String])
    case doctor
    case version
    case pair(name: String)
    case run(selections: [String]?, program: String, arguments: [String])
    case help
}

public enum CLIParseError: Error, Equatable, LocalizedError, Sendable {
    case missingCommand
    case unknownCommand(String)
    case unexpectedArguments(String)
    case missingPairName
    case missingGroupName
    case missingGroupCredentials
    case missingProfile
    case missingRunSeparator
    case missingProgram

    public var errorDescription: String? {
        switch self {
        case .missingCommand:
            "Choose pair, list, groups, doctor, run, or help."
        case .unknownCommand(let command):
            "Unknown command: \(command)"
        case .unexpectedArguments(let command):
            "The \(command) command does not accept arguments."
        case .missingPairName:
            "Use `envlatch pair <agent-or-host-name>`."
        case .missingGroupName:
            "Use `envlatch groups create <group-name> --using <saved-key> [--using <saved-key> ...]`."
        case .missingGroupCredentials:
            "Select at least one saved key with `--using`."
        case .missingProfile:
            "Use `envlatch run --using <key-or-group> [--using <key-or-group> ...] -- <program> [args...]`."
        case .missingRunSeparator:
            "Use `envlatch run -- <program> [args...]`."
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
        case "groups":
            if arguments.count == 1 {
                return .profiles
            }
            guard arguments.count >= 2, arguments[1] == "create" else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return try parseCreateGroup(arguments)
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
        case "version", "--version":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .version
        case "pair":
            guard arguments.count >= 2 else {
                throw CLIParseError.missingPairName
            }
            return .pair(name: arguments.dropFirst().joined(separator: " "))
        case "run":
            guard let separatorIndex = arguments.dropFirst().firstIndex(of: "--") else {
                throw CLIParseError.missingRunSeparator
            }
            guard arguments.index(after: separatorIndex) < arguments.endIndex else {
                throw CLIParseError.missingProgram
            }
            let programIndex = arguments.index(after: separatorIndex)
            let selectionArguments = arguments[arguments.index(after: arguments.startIndex)..<separatorIndex]
            let selections: [String]?
            if selectionArguments.isEmpty {
                selections = nil
            } else {
                selections = try parseRunSelections(selectionArguments)
            }
            return .run(
                selections: selections,
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

    private static func parseCreateGroup(_ arguments: [String]) throws -> CLICommand {
        guard arguments.count >= 3 else {
            throw CLIParseError.missingGroupName
        }
        let name = arguments[2]
        guard name != "--using" else {
            throw CLIParseError.missingGroupName
        }

        var credentials: [String] = []
        var index = 3
        while index < arguments.endIndex {
            guard arguments[index] == "--using" else {
                throw CLIParseError.unexpectedArguments("groups create")
            }
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex, arguments[valueIndex] != "--using" else {
                throw CLIParseError.missingGroupCredentials
            }
            credentials.append(arguments[valueIndex])
            index = arguments.index(after: valueIndex)
        }
        guard !credentials.isEmpty else {
            throw CLIParseError.missingGroupCredentials
        }
        return .createGroup(name: name, credentialNames: credentials)
    }

    private static func parseRunSelections(
        _ arguments: ArraySlice<String>
    ) throws -> [String] {
        var selections: [String] = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            guard arguments[index] == "--using" else {
                throw CLIParseError.missingRunSeparator
            }
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex, arguments[valueIndex] != "--using" else {
                throw CLIParseError.missingProfile
            }
            selections.append(arguments[valueIndex])
            index = arguments.index(after: valueIndex)
        }
        return selections
    }
}
