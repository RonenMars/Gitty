import Foundation
import libgit2

/// The author or committer identity attached to a git commit.
public struct Signature: Sendable, Equatable, Hashable, CustomStringConvertible {

    public let name:  String
    public let email: String
    /// Time the signature was created.
    public let date:  Date

    public var description: String { "\(name) <\(email)>" }

    public init(name: String, email: String, date: Date = Date()) {
        self.name  = name
        self.email = email
        self.date  = date
    }

    // MARK: - Internal

    /// Creates a `git_signature` pointer the caller must free with `git_signature_free`.
    func makePointer() throws -> UnsafeMutablePointer<git_signature> {
        var sig: UnsafeMutablePointer<git_signature>?
        let time = git_time_t(date.timeIntervalSince1970)
        guard git_signature_new(&sig, name, email, time, 0) == 0, let sig else {
            throw GittyError(message: "Could not create git signature for \(self)")
        }
        return sig
    }

    init(raw: UnsafePointer<git_signature>) {
        self.name  = String(cString: raw.pointee.name)
        self.email = String(cString: raw.pointee.email)
        self.date  = Date(timeIntervalSince1970: TimeInterval(raw.pointee.when.time))
    }
}
