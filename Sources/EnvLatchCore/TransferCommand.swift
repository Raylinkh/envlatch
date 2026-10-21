import Foundation

public enum TransferCommand: Equatable, Sendable {
    case identity
    case trust(name: String, publicKey: Data, address: String, port: UInt16)
    case receive(peer: String, name: String, operation: UUID, bind: String, port: UInt16 = 49271)
    case send(peer: String, name: String, operation: UUID)
    case status(peer: String, name: String, operation: UUID)

    static func parse(_ arguments: [String]) throws -> Self {
        guard let command = arguments.first else { throw CLIParseError.invalidTransfer }
        if command == "identity", arguments.count == 1 { return .identity }
        var index = 1
        var peerName: String?
        if command == "trust", arguments.count >= 2 {
            peerName = arguments[1]
            index = 2
        }
        var options: [String: String] = [:]
        while index < arguments.count {
            guard index + 1 < arguments.count, arguments[index].hasPrefix("--"),
                  options[arguments[index]] == nil, !arguments[index + 1].hasPrefix("--") else {
                throw CLIParseError.invalidTransfer
            }
            options[arguments[index]] = arguments[index + 1]
            index += 2
        }
        if command == "trust" {
            guard let name = peerName, let encoded = options.removeValue(forKey: "--public-key"),
                  let publicKey = Data(base64Encoded: encoded),
                  let address = options.removeValue(forKey: "--address") else { throw CLIParseError.invalidTransfer }
            let portText = options.removeValue(forKey: "--port") ?? "49271"
            guard let port = UInt16(portText), options.isEmpty,
                  let peer = try? TransferPeer(name: name, publicKey: publicKey, address: address, port: port) else {
                throw CLIParseError.invalidTransfer
            }
            return .trust(name: peer.name, publicKey: peer.publicKey, address: peer.address, port: peer.port)
        }
        guard let peer = options.removeValue(forKey: "--peer"), validPeerName(peer),
              let name = options.removeValue(forKey: "--using"), name.utf8.count <= 256,
              (try? CredentialName(validating: name)) != nil,
              let rawOperation = options.removeValue(forKey: "--operation"),
              let operation = UUID(uuidString: rawOperation) else { throw CLIParseError.invalidTransfer }
        switch command {
        case "receive":
            let portText = options.removeValue(forKey: "--port") ?? "49271"
            guard let bind = options.removeValue(forKey: "--bind"), TransferPeer.isTailnetAddress(bind),
                  let port = UInt16(portText), port > 0, options.isEmpty else {
                throw CLIParseError.invalidTransfer
            }
            return .receive(peer: peer, name: name, operation: operation, bind: bind, port: port)
        case "send":
            guard options.isEmpty else { throw CLIParseError.invalidTransfer }
            return .send(peer: peer, name: name, operation: operation)
        case "status":
            guard options.isEmpty else { throw CLIParseError.invalidTransfer }
            return .status(peer: peer, name: name, operation: operation)
        default: throw CLIParseError.invalidTransfer
        }
    }

    private static func validPeerName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
            && name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
