import CryptoKit
import Darwin
import Foundation
import Security
#if canImport(EnvLatchCore)
@testable import EnvLatchCore
#endif

@_silgen_name("fork")
private func transferAcceptanceFork() -> pid_t

// Shared by Swift Testing and the standalone CLT-compatible native probe.
@available(macOS 14.0, *)
struct NativeTransferAcceptanceHarness {
    func run() throws {
        let authority = try AcceptanceKeychainAuthority()
        let result = Result { try runWithOwnedKeychain() }
        try authority.requireUnchanged()
        try result.get()
    }

    private func runWithOwnedKeychain() throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try acceptanceRequire(environment["ENVLATCH_TRANSFER_ACCEPTANCE_MODE"])
        print("native_pid=\(getpid())")
        let runID = try acceptanceRequire(environment["ENVLATCH_TRANSFER_ACCEPTANCE_RUN_ID"])
        _ = try acceptanceRequire(UUID(uuidString: runID))
        let rootPath = try acceptanceRequire(environment["ENVLATCH_TRANSFER_ACCEPTANCE_ROOT"])
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let service = "dev.envlatch.transfer.acceptance.\(runID.lowercased())"
        let name = try CredentialName(validating: "ENVLATCH_TRANSFER_SENTINEL_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_TRANSFER_UNSELECTED_TOKEN")
        if mode == "scan" {
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
            var noValue = true
            var noStaging = true
            if let files {
                for case let file as URL in files {
                    if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                        let bytes = try Data(contentsOf: file)
                        noValue = noValue && bytes.range(of: Data(Self.syntheticSentinel.utf8)) == nil
                        noStaging = noStaging && file.pathExtension == "json"
                    }
                }
            }
            try acceptanceCheck(noValue)
            try acceptanceCheck(noStaging)
            print("native_no_synthetic_value_in_public_metadata=\(noValue)")
            print("native_no_unexpected_staging_files=\(noStaging)")
            return
        }

        guard let keychain = try acceptanceKeychain(root: root, runID: runID, create: mode != "cleanup") else {
            try acceptanceCheck(mode == "cleanup")
            print("native_cleanup=empty_owned_namespace")
            print("native_isolated_keychain_deleted=true")
            return
        }
        let store = KeychainSecretStore(service: service, keychain: keychain)
        let identityStore = KeychainTransferIdentityStore(service: service + ".identity", keychain: keychain)
        print("native_keychain=isolated_encrypted_file")

        if mode == "cleanup" {
            try store.delete(name: name)
            try store.delete(name: unselected)
            try KeychainSecretStore(service: service + ".identity", keychain: keychain)
                .delete(name: CredentialName(validating: "ENVLATCH_TRANSFER_PRIVATE_KEY"))
            try acceptanceCheck(try store.listNames().isEmpty)
            try acceptanceCheck(try KeychainSecretStore(service: service + ".identity", keychain: keychain).listNames().isEmpty)
            try acceptanceStatus(SecKeychainDelete(keychain))
            try acceptanceCheck(!FileManager.default.fileExists(atPath: root.appendingPathComponent("acceptance.keychain").path))
            try acceptanceCheck(!FileManager.default.fileExists(atPath: root.appendingPathComponent("acceptance.keychain-db").path))
            print("native_cleanup=empty_owned_namespace")
            print("native_isolated_keychain_deleted=true")
            return
        }

        let identity = try identityStore.loadOrCreate()
        if mode == "identity" {
            print("native_public_key=\(identity.publicKey.base64EncodedString())")
            print("native_fingerprint=\(identity.fingerprint)")
            print("native_service=\(service)")
            return
        }
        if mode == "seed" {
            try acceptanceCheck(try store.listNames().isEmpty)
            try store.create(name: name, value: Self.syntheticSentinel)
            try store.create(name: unselected, value: "public-unselected-acceptance-fixture")
            print("native_seed=two_synthetic_accounts")
            return
        }
        if mode == "verify" {
            try verifySelectedChild(store: store, name: name, unselected: unselected, root: root)
            print("native_source_or_target_exact=true")
            return
        }

        let peerKeyText = try acceptanceRequire(environment["ENVLATCH_TRANSFER_PEER_PUBLIC_KEY"])
        let peerKey = try acceptanceRequire(Data(base64Encoded: peerKeyText))
        let peerAddress = try acceptanceRequire(environment["ENVLATCH_TRANSFER_PEER_ADDRESS"])
        let portText = try acceptanceRequire(environment["ENVLATCH_TRANSFER_ACCEPTANCE_PORT"])
        let port = try acceptanceRequire(UInt16(portText))
        let peer = try TransferPeer(name: "Native Synthetic Peer", publicKey: peerKey, address: peerAddress, port: port)
        let metadata = TransferMetadataStore(directoryURL: root.appendingPathComponent("metadata"))
        do { try acceptanceCheck(try metadata.peer(named: peer.name) == peer) }
        catch TransferError.untrustedPeer { try metadata.pin(peer: peer) }
        let operationText = try acceptanceRequire(environment["ENVLATCH_TRANSFER_ACCEPTANCE_OPERATION"])
        let operation = try acceptanceRequire(UUID(uuidString: operationText))
        let receiving = mode == "receive"
        let binding = try TransferBinding(operationID: operation, credentialName: name.rawValue,
            sourceFingerprint: receiving ? peer.fingerprint : identity.fingerprint,
            targetFingerprint: receiving ? identity.fingerprint : peer.fingerprint)
        let session = TransferSession(identity: identity, peer: peer, metadata: metadata, secrets: store,
            consent: { request in
                // This proves Core's real channel and Keychain path, not production terminal approval.
                let exact = request.binding == binding && request.peer == peer
                print("native_consent=injected_test_exact_binding")
                return exact
            })

        let result: TransferRecord
        if receiving {
            let address = try acceptanceRequire(environment["ENVLATCH_TRANSFER_BIND_ADDRESS"])
            let listener = try TransferTCPListener(address: address, port: port,
                expectedPeerAddress: peerAddress, timeout: 45)
            defer { listener.close() }
            print("native_listener=ready")
            fflush(stdout)
            let connection = try listener.accept()
            defer { connection.close() }
            result = try session.receive(binding: binding, connection: connection)
        } else {
            try acceptanceCheck(mode == "send")
            let connection = try TransferTCPConnection.connect(address: peerAddress, port: port, timeout: 45)
            defer { connection.close() }
            result = try session.send(binding: binding, connection: connection)
        }
        try acceptanceCheck(result.binding == binding)
        try acceptanceCheck(result.state == .committed)
        try acceptanceCheck(result.status == "committed")
        print("native_operation=\(operation.uuidString)")
        print("native_result=\(result.status)")
        print("native_bound_peer=\(peer.fingerprint)")
        if receiving {
            try acceptanceCheck(try store.listNames() == [name])
            print("native_target_only_selected=true")
            try verifySelectedChild(store: store, name: name, unselected: unselected, root: root)
        }
    }

    private static let syntheticSentinel = "public-synthetic-envlatch-two-mac-acceptance-v1"

    private func verifySelectedChild(store: KeychainSecretStore, name: CredentialName,
                                     unselected: CredentialName, root: URL) throws {
        let application = CLIApplication(store: store, environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json")),
            launchProfileStore: LaunchProfileStore(fileURL: root.appendingPathComponent("groups.json")),
            stdout: { _ in }, stderr: { _ in })
        let expectedDigest = SHA256.hash(data: Data(Self.syntheticSentinel.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let probe = """
        import hashlib, os, sys
        exact = hashlib.sha256(os.environ.get(sys.argv[1], '').encode()).hexdigest() == sys.argv[3]
        absent = sys.argv[2] not in os.environ
        print('native_selected_exact=' + str(exact).lower())
        print('native_unselected_absent=' + str(absent).lower())
        sys.exit(0 if exact and absent else 1)
        """
        let plan = try application.prepareRun(selections: [name.rawValue], program: "/usr/bin/python3",
            arguments: ["-c", probe, name.rawValue, unselected.rawValue, expectedDigest])
        var descriptors = [Int32](repeating: 0, count: 2)
        try acceptanceCheck(pipe(&descriptors) == 0)
        let child = transferAcceptanceFork()
        try acceptanceCheck(child >= 0)
        if child == 0 {
            close(descriptors[0])
            _ = dup2(descriptors[1], STDOUT_FILENO)
            _ = dup2(descriptors[1], STDERR_FILENO)
            close(descriptors[1])
            CommandRunner.execute(plan)
        }
        close(descriptors[1])
        var receipt = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while true {
            let count = read(descriptors[0], &buffer, buffer.count)
            if count <= 0 { break }
            receipt.append(contentsOf: buffer.prefix(Int(count)))
        }
        close(descriptors[0])
        var status: Int32 = 0
        try acceptanceCheck(waitpid(child, &status, 0) == child)
        try acceptanceCheck(status == 0)
        print("native_reaped_child_pid=\(child)")
        let output = String(decoding: receipt, as: UTF8.self)
        try acceptanceCheck(output.contains("native_selected_exact=true"))
        try acceptanceCheck(output.contains("native_unselected_absent=true"))
        try acceptanceCheck(!output.contains(Self.syntheticSentinel))
        print(output, terminator: "")
    }
}

@available(macOS 14.0, *)
extension NativeTransferAcceptanceHarness {
    func runTerminal() throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try acceptanceRequire(environment["ENVLATCH_TRANSFER_TERMINAL_TEST"])
        if mode == "no-tty" {
            try acceptanceThrowsConsentRequired { try TransferTerminalConsent.requireTerminal() }
            let secrets = TerminalNoValueStore()
            let groups = LaunchProfileStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("envlatch-unused-terminal-test-\(UUID()).json"))
            let cli = TransferCLI(secrets: secrets, groups: groups, output: { _ in })
            try acceptanceThrowsConsentRequired {
                _ = try cli.run(.send(peer: "Synthetic Unpaired", name: "ENVLATCH_TERMINAL_TOKEN", operation: UUID()))
            }
            try acceptanceCheck(secrets.calls == 0)
            print("terminal_no_tty_refused_before_values=true")
            return
        }
        let expected = environment["ENVLATCH_TRANSFER_TERMINAL_EXPECT_APPROVED"] == "true"
        let source = TransferIdentity()
        let target = TransferIdentity()
        let peer = try TransferPeer(name: "Synthetic Terminal Peer", publicKey: mode == "receive" ? source.publicKey : target.publicKey,
            address: "100.64.0.2")
        let approved: Bool
        if mode == "trust" {
            approved = try TransferTerminalConsent.approveTrust(peer)
        } else {
            try acceptanceCheck(mode == "send" || mode == "receive")
            let binding = try TransferBinding(operationID: UUID(uuidString: "901B3780-B39D-4DB5-814B-D05833D0B9FC")!,
                credentialName: "ENVLATCH_TERMINAL_TOKEN", sourceFingerprint: source.fingerprint,
                targetFingerprint: target.fingerprint)
            let request = TransferConsentRequest(direction: mode == "send" ? .send : .receive,
                binding: binding, peer: peer)
            approved = try TransferTerminalConsent.approveTransfer(request)
        }
        try acceptanceCheck(approved == expected)
        print("terminal_exact_approval_matches_expected=true")
    }
}

private final class TerminalNoValueStore: TransferSecretStore {
    private(set) var calls = 0
    func contains(name: CredentialName) throws -> Bool { calls += 1; throw TransferError.invalidInput }
    func load(name: CredentialName) throws -> String { calls += 1; throw TransferError.invalidInput }
    func create(name: CredentialName, value: String) throws { calls += 1; throw TransferError.invalidInput }
}

private enum NativeAcceptanceError: Error { case checkFailed }

private struct AcceptanceKeychainAuthority {
    let defaultKeychain: SecKeychain
    let searchList: CFArray

    init() throws {
        var defaultKeychain: SecKeychain?
        var searchList: CFArray?
        try acceptanceStatus(SecKeychainCopyDefault(&defaultKeychain))
        try acceptanceStatus(SecKeychainCopySearchList(&searchList))
        self.defaultKeychain = try acceptanceRequire(defaultKeychain)
        self.searchList = try acceptanceRequire(searchList)
    }

    func requireUnchanged() throws {
        let current = try Self()
        let defaultUnchanged = CFEqual(defaultKeychain, current.defaultKeychain)
        let listUnchanged = CFEqual(searchList, current.searchList)
        try acceptanceCheck(defaultUnchanged)
        try acceptanceCheck(listUnchanged)
        print("native_default_keychain_unchanged=\(defaultUnchanged)")
        print("native_searchlist_unchanged=\(listUnchanged)")
    }
}

private func acceptanceStatus(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
        throw KeychainStoreError.osStatus(operation: "isolated acceptance Keychain", status: status)
    }
}

private func acceptanceKeychain(root: URL, runID: String, create: Bool) throws -> SecKeychain? {
    let path = root.appendingPathComponent("acceptance.keychain").path
    let marker = root.appendingPathComponent("fixture-owner.json")
    let exists = FileManager.default.fileExists(atPath: path) || FileManager.default.fileExists(atPath: path + "-db")
    if !exists && !create { return nil }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    if FileManager.default.fileExists(atPath: marker.path) {
        try acceptanceCheck(try Data(contentsOf: marker) == Data(runID.utf8))
    } else {
        try acceptanceCheck(!exists)
        try Data(runID.utf8).write(to: marker, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: marker.path)
    }
    // Public test-fixture password; never passed through a process argument or written as a staging file.
    let password = Data("public-synthetic-acceptance-keychain-password-v1".utf8)
    var keychain: SecKeychain?
    if exists {
        try acceptanceStatus(SecKeychainOpen(path, &keychain))
    } else {
        let status = password.withUnsafeBytes {
            SecKeychainCreate(path, UInt32($0.count), $0.baseAddress, false, nil, &keychain)
        }
        try acceptanceStatus(status)
    }
    let opened = try acceptanceRequire(keychain)
    let status = password.withUnsafeBytes {
        SecKeychainUnlock(opened, UInt32($0.count), $0.baseAddress, true)
    }
    try acceptanceStatus(status)
    return opened
}

private func acceptanceCheck(_ value: @autoclosure () throws -> Bool) throws {
    guard try value() else { throw NativeAcceptanceError.checkFailed }
}

private func acceptanceRequire<T>(_ value: T?) throws -> T {
    guard let value else { throw NativeAcceptanceError.checkFailed }
    return value
}

private func acceptanceThrowsConsentRequired(_ action: () throws -> Void) throws {
    do { try action() }
    catch TransferError.consentRequired { return }
    throw NativeAcceptanceError.checkFailed
}
