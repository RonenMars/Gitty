import libgit2

/// A type-safe wrapper around a git object identifier (SHA-1).
///
/// Prefer `OID` over raw `String` wherever a commit or object identity is needed —
/// the type makes it impossible to accidentally pass arbitrary strings where a
/// valid SHA is required.
public struct OID: Sendable, Hashable, Equatable, CustomStringConvertible {

    // Store the hex string so the type is trivially Sendable.
    public let sha: String

    /// Abbreviated 7-character SHA.
    public var abbreviated: String { String(sha.prefix(7)) }

    public var description: String { sha }

    // MARK: - Init

    /// Creates an `OID` from a 40-character hex string.
    /// Returns `nil` if the string is not a valid SHA-1.
    public init?(string: String) {
        var oid = git_oid()
        guard git_oid_fromstr(&oid, string) == 0 else { return nil }
        self.sha = oid.hexString
    }

    // MARK: - Internal

    init(raw: git_oid) { self.sha = raw.hexString }

    var gitOID: git_oid {
        var oid = git_oid()
        git_oid_fromstr(&oid, sha)
        return oid
    }
}
