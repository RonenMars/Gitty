import libgit2

/// A local or remote git branch.
public struct Branch: Sendable, Identifiable, Hashable {

    public var id: String { fullName }

    /// Short name, e.g. `main` or `origin/main`.
    public let name:     String
    /// Full ref name, e.g. `refs/heads/main`.
    public let fullName: String
    public let isRemote: Bool
    /// OID of the commit this branch points to.
    public let tipID:    OID

    // MARK: - Internal

    init(name: String, fullName: String, isRemote: Bool, tipID: OID) {
        self.name     = name
        self.fullName = fullName
        self.isRemote = isRemote
        self.tipID    = tipID
    }

    init?(pointer: OpaquePointer) {
        guard let fullCStr = git_reference_name(pointer) else { return nil }
        let full = String(cString: fullCStr)

        var nameCStr: UnsafePointer<CChar>?
        guard git_branch_name(&nameCStr, pointer) == 0, let nameCStr else { return nil }

        var obj: OpaquePointer?
        guard git_reference_peel(&obj, pointer, GIT_OBJECT_COMMIT) == 0, let obj else { return nil }
        let tip = git_commit_id(obj).map { OID(raw: $0.pointee) }
        git_object_free(obj)
        guard let tip else { return nil }

        self.name     = String(cString: nameCStr)
        self.fullName = full
        self.isRemote = full.hasPrefix("refs/remotes/")
        self.tipID    = tip
    }
}
