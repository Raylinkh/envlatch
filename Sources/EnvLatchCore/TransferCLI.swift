import Darwin
import Foundation

@available(macOS 14.0, *)
struct TransferCLI {
    let secrets: any TransferSecretStore
    let groups: LaunchProfileStore
    let output: (String) -> Void

    func run(_ command: TransferCommand) throws -> Int32 {
        switch command {
        case .trust, .send, .receive: try TransferTerminalConsent.requireTerminal()
        case .identity, .status: break
        }
        let metadata = TransferMetadataStore.current()
        let identity = try KeychainTransferIdentityStore().loadOrCreate()
        switch command {
        case .identity:
            output("transfer_public_key=\(identity.publicKey.base64EncodedString())")
            output("transfer_fingerprint=\(identity.fingerprint)")
            return 0
        case .trust(let name, let publicKey, let address, let port):
            let peer = try TransferPeer(name: name, publicKey: publicKey, address: address, port: port)
            guard try TransferTerminalConsent.approveTrust(peer) else { throw TransferError.denied }
            try metadata.pin(peer: peer)
            output("trusted_peer=\(peer.name)")
            output("peer_fingerprint=\(peer.fingerprint)")
            return 0
        case .send(let peerName, let name, let operation):
            let peer = try metadata.peer(named: peerName)
            let binding = try TransferBinding(operationID: operation, credentialName: name,
                sourceFingerprint: identity.fingerprint, targetFingerprint: peer.fingerprint)
            return try perform(binding: binding, metadata: metadata) {
                let connection = try TransferTCPConnection.connect(address: peer.address, port: peer.port)
                return try session(identity: identity, peer: peer, metadata: metadata).send(binding: binding, connection: connection)
            }
        case .receive(let peerName, let name, let operation, let address, let port):
            guard TransferPeer.isTailnetAddress(address) else { throw TransferError.invalidInput }
            let peer = try metadata.peer(named: peerName)
            let binding = try TransferBinding(operationID: operation, credentialName: name,
                sourceFingerprint: peer.fingerprint, targetFingerprint: identity.fingerprint)
            return try perform(binding: binding, metadata: metadata) {
                let listener = try TransferTCPListener(address: address, port: port, expectedPeerAddress: peer.address)
                defer { listener.close() }
                output("transfer_listening=\(address):\(listener.localPort)")
                output("operation=\(operation.uuidString.lowercased())")
                let connection = try listener.accept()
                return try session(identity: identity, peer: peer, metadata: metadata).receive(binding: binding, connection: connection)
            }
        case .status(let peerName, let name, let operation):
            let peer = try metadata.peer(named: peerName)
            let outgoing = try TransferBinding(operationID: operation, credentialName: name,
                sourceFingerprint: identity.fingerprint, targetFingerprint: peer.fingerprint)
            let record: TransferRecord?
            do { record = try metadata.status(binding: outgoing) }
            catch TransferError.bindingMismatch {
                let incoming = try TransferBinding(operationID: operation, credentialName: name,
                    sourceFingerprint: peer.fingerprint, targetFingerprint: identity.fingerprint)
                record = try metadata.status(binding: incoming)
            }
            if let record { return report(record) }
            output("operation=\(operation.uuidString.lowercased())")
            output("status=unknown")
            return 2
        }
    }

    private func session(identity: TransferIdentity, peer: TransferPeer, metadata: TransferMetadataStore) -> TransferSession {
        TransferSession(identity: identity, peer: peer, metadata: metadata, secrets: secrets,
            groupNames: { try groups.listWithoutMigrating().map(\.name) },
            consent: TransferTerminalConsent.approveTransfer)
    }

    private func perform(binding: TransferBinding, metadata: TransferMetadataStore,
                         action: () throws -> TransferRecord) throws -> Int32 {
        do { return report(try action()) }
        catch {
            // A durable record, including a historical commit, outranks transport errors.
            if let record = try? metadata.status(binding: binding) { return report(record) }
            output("operation=\(binding.operationID.uuidString.lowercased())")
            if let known = error as? TransferError, known == .denied || known == .consentRequired {
                output("status=not_started")
                throw known
            }
            output("status=unknown")
            throw TransferError.outcomeUnknown
        }
    }

    private func report(_ record: TransferRecord) -> Int32 {
        output("operation=\(record.binding.operationID.uuidString.lowercased())")
        output("key=\(record.binding.credentialName)")
        output("source_fingerprint=\(record.binding.sourceFingerprint)")
        output("target_fingerprint=\(record.binding.targetFingerprint)")
        output("status=\(record.status)")
        if let rejection = record.rejection { output("reason=\(rejection.rawValue)") }
        return record.state == .committed ? 0 : (record.state == .reserved ? 2 : 1)
    }
}

public enum TransferTerminalConsent {
    public static func requireTerminal() throws {
        let descriptor = open("/dev/tty", O_RDWR | O_NOCTTY | O_CLOEXEC)
        guard descriptor >= 0 else { throw TransferError.consentRequired }
        defer { _ = Darwin.close(descriptor) }
        guard isatty(descriptor) == 1 else { throw TransferError.consentRequired }
    }

    public static func approveTrust(_ peer: TransferPeer) throws -> Bool {
        let prompt = "Trust \(peer.name) at \(peer.address):\(peer.port)\n" +
            "Peer SHA-256 fingerprint: \(peer.fingerprint)\n" +
            "Compare the complete fingerprint through a trusted independent path.\n" +
            "Type that complete fingerprint to approve: "
        return try approve(prompt: prompt, expected: peer.fingerprint)
    }

    public static func approveTransfer(_ request: TransferConsentRequest) throws -> Bool {
        let binding = request.binding
        let operation = binding.operationID.uuidString.lowercased()
        let prompt = "\(request.direction.rawValue.capitalized) key \(binding.credentialName)\n" +
            "Peer: \(request.peer.name) (\(request.peer.address))\n" +
            "Source fingerprint: \(binding.sourceFingerprint)\n" +
            "Target fingerprint: \(binding.targetFingerprint)\n" +
            "Operation: \(operation)\nCopy only; existing target names are refused.\n" +
            "Type the complete operation UUID to approve: "
        return try approve(prompt: prompt, expected: operation)
    }

private static func approve(prompt: String, expected: String) throws -> Bool {
    let descriptor = open("/dev/tty", O_RDWR | O_NOCTTY | O_CLOEXEC)
    guard descriptor >= 0, isatty(descriptor) == 1 else {
        if descriptor >= 0 { _ = Darwin.close(descriptor) }
        throw TransferError.consentRequired
    }
    defer { _ = Darwin.close(descriptor) }
    let promptData = Data(prompt.utf8)
    try promptData.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw TransferError.consentRequired }
            offset += count
        }
    }
    var answer: [UInt8] = []
    let deadline = DispatchTime.now().uptimeNanoseconds + 120_000_000_000
    while answer.count <= 128 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { throw TransferError.timeout }
        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let remaining = Int32((deadline - now) / 1_000_000 + 1)
        let ready = poll(&pollDescriptor, 1, remaining)
        if ready < 0, errno == EINTR { continue }
        guard ready > 0 else { throw TransferError.timeout }
        var byte: UInt8 = 0
        let count = Darwin.read(descriptor, &byte, 1)
        if count < 0, errno == EINTR { continue }
        guard count == 1 else { throw TransferError.consentRequired }
        if byte == 10 || byte == 13 { return String(bytes: answer, encoding: .utf8) == expected }
        answer.append(byte)
    }
    return false
}
}
