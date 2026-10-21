import CryptoKit
import Darwin
import Foundation

/// Public trust and operation receipts only. Credential bytes never enter this store.
public struct TransferMetadataStore: Sendable {
    public let directoryURL: URL
    public init(directoryURL: URL) { self.directoryURL = directoryURL }
    public static func current() -> Self {
        Self(directoryURL: PersistenceNamespace.applicationSupportDirectory
            .appendingPathComponent("transfer-v1", isDirectory: true))
    }

    public func pin(peer: TransferPeer) throws {
        _ = try TransferPeer(name: peer.name, publicKey: peer.publicKey, address: peer.address, port: peer.port)
        guard try create(peer, at: peerURL(peer.name)) else { throw TransferError.trustAlreadyExists }
    }

    public func peer(named name: String) throws -> TransferPeer {
        guard let peer: TransferPeer = try read(at: peerURL(name)) else { throw TransferError.untrustedPeer }
        guard peer.name.lowercased() == name.lowercased() else { throw TransferError.metadata }
        return try TransferPeer(name: peer.name, publicKey: peer.publicKey, address: peer.address, port: peer.port)
    }

    public func status(binding: TransferBinding) throws -> TransferRecord? {
        try validate(binding)
        guard let record: TransferRecord = try read(at: recordURL(binding)) else { return nil }
        guard record.binding == binding else { throw TransferError.bindingMismatch }
        guard (record.state == .rejected) == (record.rejection != nil) else { throw TransferError.metadata }
        return record
    }

    /// Exclusive reservation is the single durable delivery authority across processes/restarts.
    @discardableResult
    public func reserve(binding: TransferBinding) throws -> Bool {
        try validate(binding)
        let created = try create(TransferRecord(binding: binding, state: .reserved), at: recordURL(binding))
        if !created { _ = try status(binding: binding) }
        return created
    }

    func finish(_ record: TransferRecord) throws {
        guard let current = try status(binding: record.binding), current.state == .reserved,
              record.state != .reserved,
              (record.state == .rejected) == (record.rejection != nil) else { throw TransferError.metadata }
        let url = recordURL(record.binding)
        let temporary = directoryURL.appendingPathComponent("receipt-\(UUID().uuidString).tmp")
        defer { _ = unlink(temporary.path) }
        guard try create(record, at: temporary) else { throw TransferError.metadata }
        guard rename(temporary.path, url.path) == 0 else { throw TransferError.metadata }
        try syncDirectory()
    }

    private func peerURL(_ name: String) -> URL {
        let digest = SHA256.hash(data: Data(name.lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
        return directoryURL.appendingPathComponent("peer-\(digest).json")
    }

    private func validate(_ binding: TransferBinding) throws {
        _ = try TransferBinding(operationID: binding.operationID, credentialName: binding.credentialName,
                                sourceFingerprint: binding.sourceFingerprint, targetFingerprint: binding.targetFingerprint)
    }

    private func recordURL(_ binding: TransferBinding) -> URL {
        directoryURL.appendingPathComponent("operation-\(binding.operationID.uuidString.lowercased()).json")
    }

    private func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw TransferError.metadata }
        var info = stat()
        guard lstat(directoryURL.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else { throw TransferError.metadata }
    }

    private func create<T: Encodable>(_ value: T, at url: URL) throws -> Bool {
        try prepareDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(value) } catch { throw TransferError.metadata }
        guard data.count <= 16_384 else { throw TransferError.metadata }
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        if fd < 0, errno == EEXIST { return false }
        guard fd >= 0 else { throw TransferError.metadata }
        defer { _ = Darwin.close(fd) }
        try data.withUnsafeBytes { buffer in
            var written = 0
            while written < buffer.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: written), buffer.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw TransferError.metadata }
                written += count
            }
        }
        guard fsync(fd) == 0 else { throw TransferError.metadata }
        try syncDirectory()
        return true
    }

    private func read<T: Decodable>(at url: URL) throws -> T? {
        try prepareDirectory()
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0, errno == ENOENT { return nil }
        guard fd >= 0 else { throw TransferError.metadata }
        defer { _ = Darwin.close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0,
              info.st_size > 0, info.st_size <= 16_384 else { throw TransferError.metadata }
        var data = Data(count: Int(info.st_size))
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.read(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw TransferError.metadata }
                offset += count
            }
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw TransferError.metadata }
    }

    private func syncDirectory() throws {
        let fd = open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw TransferError.metadata }
        defer { _ = Darwin.close(fd) }
        guard fsync(fd) == 0 else { throw TransferError.metadata }
    }
}
