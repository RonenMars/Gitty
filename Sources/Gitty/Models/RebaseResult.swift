/// The outcome of a rebase operation.
public enum RebaseResult: Sendable {
    /// All commits were successfully rebased. The associated array contains the new commits.
    case success([Commit])
    /// The rebase was aborted due to conflicts. Resolve the listed files, then call
    /// `repository.continueRebase(author:)` or `repository.abortRebase()`.
    case conflict([ConflictedFile])
}
