import libgit2

/// A reference-counted wrapper that owns an `OpaquePointer` and calls
/// the appropriate libgit2 free function on deinit.
///
/// Using `GitPointer` eliminates scattered `defer { git_X_free(ptr) }` calls
/// and makes ownership explicit.
final class GitPointer: @unchecked Sendable {
    let raw: OpaquePointer
    private let cleanup: (OpaquePointer) -> Void

    init(_ raw: OpaquePointer, cleanup: @escaping (OpaquePointer) -> Void) {
        self.raw = raw
        self.cleanup = cleanup
    }

    deinit { cleanup(raw) }
}

// MARK: - Convenience factories

extension GitPointer {
    static func repository(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_repository_free($0) }
    }
    static func commit(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_commit_free($0) }
    }
    static func reference(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_reference_free($0) }
    }
    static func remote(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_remote_free($0) }
    }
    static func tree(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_tree_free($0) }
    }
    static func index(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_index_free($0) }
    }
    static func tag(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_tag_free($0) }
    }
    static func revwalk(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_revwalk_free($0) }
    }
    static func blame(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_blame_free($0) }
    }
    static func diff(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_diff_free($0) }
    }
    static func patch(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_patch_free($0) }
    }
    static func annotatedCommit(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_annotated_commit_free($0) }
    }
    static func rebase(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_rebase_free($0) }
    }
    static func worktree(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_worktree_free($0) }
    }
    static func object(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_object_free($0) }
    }
    static func signature(_ p: UnsafeMutablePointer<git_signature>) -> GitPointer {
        GitPointer(OpaquePointer(p)) { git_signature_free(UnsafeMutablePointer<git_signature>($0)) }
    }
    static func conflictIterator(_ p: OpaquePointer) -> GitPointer {
        GitPointer(p) { git_index_conflict_iterator_free($0) }
    }
}
