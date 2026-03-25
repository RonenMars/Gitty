import libgit2

extension Repository {

    /// Rebases the current branch onto `target`.
    ///
    /// ```swift
    /// switch try repo.rebase(onto: mainBranch, author: author) {
    /// case .success(let commits): print("Rebased \(commits.count) commits.")
    /// case .conflict(let files):  print("Resolve: \(files.map(\.path))")
    /// }
    /// ```
    public func rebase(onto target: Branch, author: Signature) throws -> RebaseResult {
        var refPtr: OpaquePointer?
        guard git_reference_lookup(&refPtr, pointer, target.fullName) == 0, let refPtr else {
            throw GittyError(message: "Branch '\(target.name)' not found")
        }
        let ref = GitPointer.reference(refPtr)

        var ontoPtr: OpaquePointer?
        guard git_annotated_commit_from_ref(&ontoPtr, pointer, ref.raw) == 0, let ontoPtr else {
            throw GittyError(message: "Could not create annotated commit from '\(target.name)'")
        }
        let onto = GitPointer.annotatedCommit(ontoPtr)

        var opts = git_rebase_options()
        git_rebase_init_options(&opts, UInt32(GIT_REBASE_OPTIONS_VERSION))

        var rebasePtr: OpaquePointer?
        let initCode = git_rebase_init(&rebasePtr, pointer, nil, onto.raw, nil, &opts)
        guard initCode == 0, let rebasePtr else { throw GittyError(code: initCode) }
        let rebase = GitPointer.rebase(rebasePtr)

        let sigPtr = try author.makePointer()
        let sig    = GitPointer.signature(sigPtr)

        var applied: [Commit] = []

        while true {
            var opPtr: UnsafeMutablePointer<git_rebase_operation>?
            let nextCode = git_rebase_next(&opPtr, rebase.raw)
            if nextCode == GIT_ITEROVER.rawValue { break }
            if nextCode != 0 {
                let conflicts = collectConflicts(in: pointer)
                if !conflicts.isEmpty {
                    git_rebase_abort(rebase.raw)
                    return .conflict(conflicts)
                }
                git_rebase_abort(rebase.raw)
                throw GittyError(code: nextCode)
            }

            var commitOID = git_oid()
            let commitCode = git_rebase_commit(&commitOID, rebase.raw, nil, sigPtr, nil, nil)

            if commitCode == GIT_EMERGECONFLICT.rawValue || commitCode == GIT_ECONFLICT.rawValue {
                let conflicts = collectConflicts(in: pointer)
                git_rebase_abort(rebase.raw)
                return .conflict(conflicts.isEmpty ? [ConflictedFile(path: "unknown")] : conflicts)
            }
            // GIT_EAPPLIED means the commit is a no-op (already applied) — skip silently
            if commitCode != 0 && commitCode != -35 {
                git_rebase_abort(rebase.raw)
                throw GittyError(code: commitCode)
            }

            if commitCode == 0 {
                var ptr: OpaquePointer?
                if git_commit_lookup(&ptr, pointer, &commitOID) == 0, let ptr {
                    let box = GitPointer.commit(ptr)
                    applied.append(Commit(pointer: box.raw))
                }
            }
        }

        _ = sig
        let finishCode = git_rebase_finish(rebase.raw, sigPtr)
        guard finishCode == 0 else { throw GittyError(code: finishCode) }

        return .success(applied)
    }

    /// Aborts an in-progress rebase, restoring the repository to its pre-rebase state.
    public func abortRebase() throws {
        var rebasePtr: OpaquePointer?
        var opts = git_rebase_options()
        git_rebase_init_options(&opts, UInt32(GIT_REBASE_OPTIONS_VERSION))
        guard git_rebase_open(&rebasePtr, pointer, &opts) == 0, let rebasePtr else {
            throw GittyError(message: "No rebase in progress")
        }
        let rebase = GitPointer.rebase(rebasePtr)
        let code   = git_rebase_abort(rebase.raw)
        guard code == 0 else { throw GittyError(code: code) }
    }
}
