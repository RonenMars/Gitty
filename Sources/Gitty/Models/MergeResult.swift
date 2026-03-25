/// The outcome of a `repository.merge(branch:)` call.
public enum MergeResult: Sendable {
    /// Both branches already point to the same commit.
    case upToDate
    /// HEAD was fast-forwarded; the associated `Commit` is the new HEAD.
    case fastForward(Commit)
    /// A three-way merge succeeded and the index is staged.
    /// Call `repository.commit(message:author:)` to create the merge commit.
    case merged
    /// Automatic merge failed due to conflicts. Resolve each file, then commit.
    case conflict([ConflictedFile])
}

/// A file with an unresolved merge or rebase conflict.
public struct ConflictedFile: Sendable, Identifiable {
    public var id: String { path }
    public let path: String
}
