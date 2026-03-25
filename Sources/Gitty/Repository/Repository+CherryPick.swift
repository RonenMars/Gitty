import libgit2

/// The outcome of a cherry-pick operation.
public enum CherryPickResult: Sendable {
    /// The commit was applied cleanly. Call `commit(message:author:)` to record it.
    case success
    /// The cherry-pick produced conflicts. Resolve the listed files, then commit.
    case conflict([ConflictedFile])
}

extension Repository {

    /// Applies the changes introduced by `commit` onto the current branch.
    ///
    /// On success the index is staged with the cherry-picked changes.
    /// Call `commit(message:author:)` (optionally with the original commit's message)
    /// to finish.
    ///
    /// ```swift
    /// switch try repo.cherryPick(commit) {
    /// case .success:
    ///     try repo.commit(message: commit.message, author: author)
    /// case .conflict(let files):
    ///     print("Conflicts in: \(files.map(\.path))")
    /// }
    /// ```
    public func cherryPick(_ commit: Commit) throws -> CherryPickResult {
        var oid = commit.id.gitOID
        var commitPtr: OpaquePointer?
        guard git_commit_lookup(&commitPtr, pointer, &oid) == 0, let commitPtr else {
            throw GittyError(message: "Could not look up commit \(commit.id.abbreviated)")
        }
        let commitBox = GitPointer.commit(commitPtr)

        var opts = git_cherrypick_options()
        git_cherrypick_init_options(&opts, UInt32(GIT_CHERRYPICK_OPTIONS_VERSION))
        opts.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue | GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

        let code = git_cherrypick(pointer, commitBox.raw, &opts)

        if code == GIT_EMERGECONFLICT.rawValue || code == GIT_ECONFLICT.rawValue {
            let conflicts = collectConflicts(in: pointer)
            return .conflict(conflicts)
        }
        guard code == 0 else { throw GittyError(code: code) }

        let conflicts = collectConflicts(in: pointer)
        if !conflicts.isEmpty { return .conflict(conflicts) }

        return .success
    }
}
