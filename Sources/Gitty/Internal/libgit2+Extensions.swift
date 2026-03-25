import libgit2

// MARK: - git_oid

extension git_oid {
    /// 40-character hex SHA-1 string.
    var hexString: String {
        var copy = self
        var buf  = [CChar](repeating: 0, count: 41)
        git_oid_tostr(&buf, 41, &copy)
        return String(cString: buf)
    }
}

// MARK: - Commit lookup

func lookupCommitPointer(oid: inout git_oid, in repo: OpaquePointer) throws -> GitPointer {
    var ptr: OpaquePointer?
    let code = git_commit_lookup(&ptr, repo, &oid)
    guard code == 0, let ptr else { throw GittyError(code: code) }
    return .commit(ptr)
}

// MARK: - HEAD

func headCommitPointer(in repo: OpaquePointer) -> GitPointer? {
    var headRef: OpaquePointer?
    guard git_repository_head(&headRef, repo) == 0, let headRef else { return nil }
    let ref = GitPointer.reference(headRef)
    var obj: OpaquePointer?
    guard git_reference_peel(&obj, ref.raw, GIT_OBJECT_COMMIT) == 0, let obj else { return nil }
    return .commit(obj)
}

// MARK: - Index conflicts

func collectConflicts(in repo: OpaquePointer) -> [ConflictedFile] {
    var idxPtr: OpaquePointer?
    guard git_repository_index(&idxPtr, repo) == 0, let idxPtr else { return [] }
    let idx = GitPointer.index(idxPtr)

    var iterPtr: OpaquePointer?
    guard git_index_conflict_iterator_new(&iterPtr, idx.raw) == 0, let iterPtr else { return [] }
    let iter = GitPointer.conflictIterator(iterPtr)

    var result: [ConflictedFile] = []
    var ancestor, ours, theirs: UnsafePointer<git_index_entry>?
    while git_index_conflict_next(&ancestor, &ours, &theirs, iter.raw) == 0 {
        let pathPtr = (ours ?? theirs ?? ancestor)?.pointee.path
        let path    = pathPtr.map { String(cString: $0) } ?? ""
        result.append(ConflictedFile(path: path))
    }
    return result
}

// MARK: - Tree from ref

func treePointer(refName: String, in repo: OpaquePointer) throws -> GitPointer {
    var obj: OpaquePointer?
    guard git_revparse_single(&obj, repo, refName) == 0, let obj else {
        throw GittyError(message: "Could not resolve '\(refName)'")
    }
    let objBox = GitPointer.object(obj)
    var treePtr: OpaquePointer?
    guard git_object_peel(&treePtr, objBox.raw, GIT_OBJECT_TREE) == 0, let treePtr else {
        throw GittyError(message: "Could not peel '\(refName)' to a tree")
    }
    return .tree(treePtr)
}

func treePointer(forCommitOID sha: String, in repo: OpaquePointer) throws -> GitPointer {
    var oid = git_oid()
    guard git_oid_fromstr(&oid, sha) == 0 else {
        throw GittyError(message: "Invalid OID: \(sha)")
    }
    var commitPtr: OpaquePointer?
    guard git_commit_lookup(&commitPtr, repo, &oid) == 0, let commitPtr else {
        throw GittyError(message: "Could not look up commit \(sha.prefix(7))")
    }
    let commit = GitPointer.commit(commitPtr)
    var treePtr: OpaquePointer?
    guard git_commit_tree(&treePtr, commit.raw) == 0, let treePtr else {
        throw GittyError(message: "Could not get tree for commit \(sha.prefix(7))")
    }
    return .tree(treePtr)
}
