import Foundation

public enum CLICommand: Equatable, Sendable {
    case list
    case doctor
    case run(program: String, arguments: [String])
    case help
}

public enum CLIParseError: Error, Equatable, LocalizedError, Sendable {
    case missingCommand
    case unknownCommand(String)
    case unexpectedArguments(String)
    case missingRunSeparator
    case missingProgram

    public var errorDescription: String? {
        switch self {
        case .missingCommand:
            "Choose list, doctor, or run."
        case .unknownCommand(let command):
            "Unknown command: \(command)"
        case .unexpectedArguments(let command):
            "The \(command) command does not accept arguments."
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
        case "doctor":
            guard arguments.count == 1 else {
                throw CLIParseError.unexpectedArguments(command)
            }
            return .doctor
        case "run":
            guard arguments.count >= 2, arguments[1] == "--" else {
                throw CLIParseError.missingRunSeparator
            }
            guard arguments.count >= 3 else {
                throw CLIParseError.missingProgram
            }
            return .run(program: arguments[2], arguments: Array(arguments.dropFirst(3)))
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
