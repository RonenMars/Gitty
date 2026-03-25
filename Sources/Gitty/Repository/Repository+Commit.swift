import libgit2

extension Repository {

    /// Commits whatever is currently staged in the index.
    ///
    /// Call `stage(paths:)` or `stageAll()` before this if you need to change
    /// what is included.
    ///
    /// ```swift
    /// try repo.stage(paths: ["Sources/Login.swift"])
    /// let commit = try repo.commit(
    ///     message: "feat: add login screen",
    ///     author: Signature(name: "Alice", email: "alice@example.com")
    /// )
    /// ```
    @discardableResult
    public func commit(message: String, author: Signature) throws -> Commit {
        let idx = try openIndex()

        var treeOID = git_oid()
        guard git_index_write_tree(&treeOID, idx.raw) == 0 else {
            throw GittyError(message: "Could not write tree from index")
        }
        var treePtr: OpaquePointer?
        guard git_tree_lookup(&treePtr, pointer, &treeOID) == 0, let treePtr else {
            throw GittyError(message: "Could not look up tree")
        }
        let tree = GitPointer.tree(treePtr)

        let sigPtr  = try author.makePointer()
        let sig     = GitPointer.signature(sigPtr)

        let parentCommit = headCommitPointer(in: pointer)

        var commitOID = git_oid()
        let code: Int32

        if let parent = parentCommit {
            var parents: [OpaquePointer?] = [parent.raw]
            code = parents.withUnsafeMutableBufferPointer { buf in
                git_commit_create(&commitOID, pointer, "HEAD",
                                  sigPtr, sigPtr, nil, message, tree.raw,
                                  1, buf.baseAddress)
            }
        } else {
            code = git_commit_create(&commitOID, pointer, "HEAD",
                                     sigPtr, sigPtr, nil, message, tree.raw,
                                     0, nil)
        }

        _ = sig  // keep alive
        guard code == 0 else { throw GittyError(code: code) }

        let commitPtr = try lookupCommitPointer(oid: &commitOID, in: pointer)
        return Commit(pointer: commitPtr.raw)
    }
}
