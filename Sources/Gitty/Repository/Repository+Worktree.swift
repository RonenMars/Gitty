import Foundation
import libgit2

/// A linked working tree attached to a repository.
public struct Worktree: Sendable, Identifiable {
    public var id: String { name }
    public let name:   String
    public let path:   URL
    public let isLocked: Bool
}

extension Repository {

    // MARK: - List

    /// Returns all linked worktrees for this repository.
    public func worktreeList() throws -> [Worktree] {
        var list = git_strarray()
        let code = git_worktree_list(&list, pointer)
        guard code == 0 else { throw GittyError(code: code) }
        defer { git_strarray_free(&list) }

        var result: [Worktree] = []
        for i in 0..<list.count {
            guard let nameCStr = list.strings?[i] else { continue }
            let name = String(cString: nameCStr)

            var wtPtr: OpaquePointer?
            guard git_worktree_lookup(&wtPtr, pointer, nameCStr) == 0, let wtPtr else { continue }
            let wt = GitPointer.worktree(wtPtr)

            let pathCStr = git_worktree_path(wt.raw)
            let path     = pathCStr.map { URL(fileURLWithPath: String(cString: $0)) }
                        ?? workingDirectory.appendingPathComponent(name)
            let locked   = git_worktree_is_locked(nil, wt.raw) != 0

            result.append(Worktree(name: name, path: path, isLocked: locked))
        }
        return result
    }

    // MARK: - Add

    /// Creates a new linked worktree at `path`, optionally checking out a new branch named `branch`.
    @discardableResult
    public func addWorktree(name: String, path: URL, branch: String? = nil) throws -> Worktree {
        var opts = git_worktree_add_options()
        git_worktree_add_init_options(&opts, UInt32(GIT_WORKTREE_ADD_OPTIONS_VERSION))

        var refPtr: OpaquePointer?
        if let branch {
            // Create or look up the branch reference
            var headCommitPtr: OpaquePointer?
            if let head = headCommitPointer(in: pointer) {
                var existing: OpaquePointer?
                if git_branch_lookup(&existing, pointer, branch, GIT_BRANCH_LOCAL) == 0, let existing {
                    refPtr = existing
                } else {
                    _ = git_branch_create(&refPtr, pointer, branch, head.raw, 0)
                }
            }
            opts.ref = refPtr
        }
        defer { if let refPtr { git_reference_free(refPtr) } }

        var wtPtr: OpaquePointer?
        let code = git_worktree_add(&wtPtr, pointer, name, path.path, &opts)
        guard code == 0, let wtPtr else { throw GittyError(code: code) }
        let wt = GitPointer.worktree(wtPtr)

        let pathCStr = git_worktree_path(wt.raw)
        let wtPath   = pathCStr.map { URL(fileURLWithPath: String(cString: $0)) } ?? path
        let locked   = git_worktree_is_locked(nil, wt.raw) != 0
        return Worktree(name: name, path: wtPath, isLocked: locked)
    }

    // MARK: - Remove

    /// Prunes (removes) the linked worktree with the given name.
    public func removeWorktree(named name: String) throws {
        var wtPtr: OpaquePointer?
        guard git_worktree_lookup(&wtPtr, pointer, name) == 0, let wtPtr else {
            throw GittyError(message: "Worktree '\(name)' not found")
        }
        let wt = GitPointer.worktree(wtPtr)

        var opts = git_worktree_prune_options()
        git_worktree_prune_init_options(&opts, UInt32(GIT_WORKTREE_PRUNE_OPTIONS_VERSION))
        opts.flags = GIT_WORKTREE_PRUNE_VALID.rawValue

        let code = git_worktree_prune(wt.raw, &opts)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Lock / Unlock

    /// Locks a worktree to prevent it from being pruned.
    public func lockWorktree(named name: String, reason: String? = nil) throws {
        var wtPtr: OpaquePointer?
        guard git_worktree_lookup(&wtPtr, pointer, name) == 0, let wtPtr else {
            throw GittyError(message: "Worktree '\(name)' not found")
        }
        let wt   = GitPointer.worktree(wtPtr)
        let code = git_worktree_lock(wt.raw, reason)
        guard code == 0 else { throw GittyError(code: code) }
    }

    /// Unlocks a previously locked worktree.
    public func unlockWorktree(named name: String) throws {
        var wtPtr: OpaquePointer?
        guard git_worktree_lookup(&wtPtr, pointer, name) == 0, let wtPtr else {
            throw GittyError(message: "Worktree '\(name)' not found")
        }
        let wt   = GitPointer.worktree(wtPtr)
        let code = git_worktree_unlock(wt.raw)
        guard code == 0 else { throw GittyError(code: code) }
    }
}
