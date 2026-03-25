import libgit2

extension Repository {

    /// Merges the given branch into the current branch.
    ///
    /// ```swift
    /// switch try repo.merge(branch: feature) {
    /// case .upToDate:          print("Already up-to-date.")
    /// case .fastForward(let c): print("Fast-forwarded to \(c.id.abbreviated).")
    /// case .merged:            try repo.commit(message: "Merge '\(feature.name)'", author: author)
    /// case .conflict(let fs):  print("Conflicts: \(fs.map(\.path))")
    /// }
    /// ```
    public func merge(branch: Branch) throws -> MergeResult {
        var refPtr: OpaquePointer?
        guard git_reference_lookup(&refPtr, pointer, branch.fullName) == 0, let refPtr else {
            throw GittyError(message: "Branch '\(branch.name)' not found")
        }
        let ref = GitPointer.reference(refPtr)

        var annotatedPtr: OpaquePointer?
        guard git_annotated_commit_from_ref(&annotatedPtr, pointer, ref.raw) == 0, let annotatedPtr else {
            throw GittyError(message: "Could not create annotated commit from '\(branch.name)'")
        }
        let annotated = GitPointer.annotatedCommit(annotatedPtr)

        var analysis:   git_merge_analysis_t    = GIT_MERGE_ANALYSIS_NONE
        var preference: git_merge_preference_t  = GIT_MERGE_PREFERENCE_NONE
        var heads: [OpaquePointer?] = [annotated.raw]
        let code = heads.withUnsafeMutableBufferPointer { buf in
            git_merge_analysis(&analysis, &preference, pointer, buf.baseAddress, 1)
        }
        guard code == 0 else { throw GittyError(code: code) }

        // ── Up to date ────────────────────────────────────────────────────────
        if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
            return .upToDate
        }

        // ── Fast-forward ──────────────────────────────────────────────────────
        if analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
            guard let oidPtr = git_annotated_commit_id(annotated.raw) else {
                throw GittyError(message: "Could not get OID for fast-forward")
            }
            var commitPtr: OpaquePointer?
            guard git_commit_lookup(&commitPtr, pointer, oidPtr) == 0, let commitPtr else {
                throw GittyError(code: -1)
            }
            let commitBox = GitPointer.commit(commitPtr)

            var treePtr: OpaquePointer?
            guard git_commit_tree(&treePtr, commitBox.raw) == 0, let treePtr else {
                throw GittyError(message: "Could not get tree for fast-forward commit")
            }
            let tree = GitPointer.tree(treePtr)

            var checkoutOpts = git_checkout_options()
            git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
            checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
            guard git_checkout_tree(pointer, tree.raw, &checkoutOpts) == 0 else {
                throw GittyError(message: "Fast-forward checkout failed")
            }

            var headRef: OpaquePointer?
            if git_repository_head(&headRef, pointer) == 0, let headRef {
                let hr = GitPointer.reference(headRef)
                var oidCopy = oidPtr.pointee
                var updated: OpaquePointer?
                _ = git_reference_set_target(&updated, hr.raw, &oidCopy, "merge: Fast-forward")
                if let updated { git_reference_free(updated) }
            }
            return .fastForward(Commit(pointer: commitBox.raw))
        }

        // ── Three-way merge ───────────────────────────────────────────────────
        var mergeOpts = git_merge_options()
        git_merge_init_options(&mergeOpts, UInt32(GIT_MERGE_OPTIONS_VERSION))
        var checkoutOpts = git_checkout_options()
        git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue | GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

        var heads2: [OpaquePointer?] = [annotated.raw]
        let mergeCode = heads2.withUnsafeMutableBufferPointer { buf in
            git_merge(pointer, buf.baseAddress, 1, &mergeOpts, &checkoutOpts)
        }
        guard mergeCode == 0 else { throw GittyError(code: mergeCode) }

        let conflicts = collectConflicts(in: pointer)
        if !conflicts.isEmpty { return .conflict(conflicts) }

        return .merged
    }
}
