import libgit2

/// A single git commit.
public struct Commit: Sendable, Identifiable, Hashable {

    public let id:         OID
    public let message:    String
    public let author:     Signature
    public let committer:  Signature
    public let parentIDs:  [OID]

    /// First line of the commit message.
    public var subject: String {
        message.components(separatedBy: "\n").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    /// Body text after the subject line (may be empty).
    public var body: String {
        let lines = message.components(separatedBy: "\n").dropFirst()
        return lines.drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .joined(separator: "\n")
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: Commit, rhs: Commit) -> Bool { lhs.id == rhs.id }

    // MARK: - Internal

    init(pointer: OpaquePointer) {
        let rawOID = git_commit_id(pointer)
        self.id = rawOID.map { OID(raw: $0.pointee) } ?? OID(string: "0000000000000000000000000000000000000000")!

        self.message   = git_commit_message(pointer).map { String(cString: $0) } ?? ""
        self.author    = git_commit_author(pointer).map    { Signature(raw: $0) } ?? Signature(name: "", email: "")
        self.committer = git_commit_committer(pointer).map { Signature(raw: $0) } ?? Signature(name: "", email: "")

        var parents: [OID] = []
        for i in 0..<git_commit_parentcount(pointer) {
            if let p = git_commit_parent_id(pointer, i) { parents.append(OID(raw: p.pointee)) }
        }
        self.parentIDs = parents
    }
}
