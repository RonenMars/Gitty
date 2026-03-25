import libgit2

/// Namespace for branch operations: `repo.branches.create(...)`, etc.
public struct BranchOperations: Sendable {
    let repository: Repository

    // MARK: - List

    /// Lists local or remote branches.
    public func list(type: BranchType = .local) throws -> [Branch] {
        let kind: git_branch_t = type == .remote ? GIT_BRANCH_REMOTE : GIT_BRANCH_LOCAL
        var iter: OpaquePointer?
        guard git_branch_iterator_new(&iter, repository.pointer, kind) == 0, let iter else {
            throw GittyError(message: "Could not create branch iterator")
        }
        defer { git_branch_iterator_free(iter) }

        var branches: [Branch] = []
        var ref: OpaquePointer?
        var branchKind: git_branch_t = GIT_BRANCH_LOCAL
        while git_branch_next(&ref, &branchKind, iter) == 0 {
            if let r = ref {
                if let b = Branch(pointer: r) { branches.append(b) }
                git_reference_free(r)
                ref = nil
            }
        }
        return branches
    }

    // MARK: - Create

    /// Creates a new local branch pointing at `commit`.
    @discardableResult
    public func create(named name: String, at commit: Commit, force: Bool = false) throws -> Branch {
        var oid = commit.id.gitOID
        var commitPtr: OpaquePointer?
        guard git_commit_lookup(&commitPtr, repository.pointer, &oid) == 0, let commitPtr else {
            throw GittyError(message: "Could not look up commit \(commit.id.abbreviated)")
        }
        let commitBox = GitPointer.commit(commitPtr)

        var refPtr: OpaquePointer?
        let code = git_branch_create(&refPtr, repository.pointer, name, commitBox.raw, force ? 1 : 0)
        guard code == 0, let refPtr else { throw GittyError(code: code) }
        let ref = GitPointer.reference(refPtr)

        guard let branch = Branch(pointer: ref.raw) else {
            throw GittyError(message: "Could not read newly created branch '\(name)'")
        }
        return branch
    }

    // MARK: - Delete

    /// Deletes the local branch with the given name.
    public func delete(named name: String) throws {
        var refPtr: OpaquePointer?
        guard git_branch_lookup(&refPtr, repository.pointer, name, GIT_BRANCH_LOCAL) == 0, let refPtr else {
            throw GittyError(message: "Branch '\(name)' not found")
        }
        let ref  = GitPointer.reference(refPtr)
        let code = git_branch_delete(ref.raw)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Rename

    /// Renames `oldName` to `newName`.
    @discardableResult
    public func rename(from oldName: String, to newName: String, force: Bool = false) throws -> Branch {
        var refPtr: OpaquePointer?
        guard git_branch_lookup(&refPtr, repository.pointer, oldName, GIT_BRANCH_LOCAL) == 0, let refPtr else {
            throw GittyError(message: "Branch '\(oldName)' not found")
        }
        let ref = GitPointer.reference(refPtr)

        var newRefPtr: OpaquePointer?
        let code = git_branch_move(&newRefPtr, ref.raw, newName, force ? 1 : 0)
        guard code == 0, let newRefPtr else { throw GittyError(code: code) }
        let newRef = GitPointer.reference(newRefPtr)

        guard let branch = Branch(pointer: newRef.raw) else {
            throw GittyError(message: "Could not read renamed branch '\(newName)'")
        }
        return branch
    }

    // MARK: - Checkout

    /// Checks out the given branch, updating HEAD and the working tree.
    public func checkout(_ branch: Branch) throws {
        var refPtr: OpaquePointer?
        guard git_reference_lookup(&refPtr, repository.pointer, branch.fullName) == 0, let refPtr else {
            throw GittyError(message: "Branch '\(branch.name)' not found")
        }
        let ref = GitPointer.reference(refPtr)

        var obj: OpaquePointer?
        guard git_reference_peel(&obj, ref.raw, GIT_OBJECT_TREE) == 0, let obj else {
            throw GittyError(message: "Could not peel branch to tree")
        }
        let tree = GitPointer.object(obj)

        var opts = git_checkout_options()
        git_checkout_init_options(&opts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

        guard git_checkout_tree(repository.pointer, tree.raw, &opts) == 0 else {
            throw GittyError(message: "Checkout failed for branch '\(branch.name)'")
        }
        let code = git_repository_set_head(repository.pointer, branch.fullName)
        guard code == 0 else { throw GittyError(code: code) }
    }
}

/// Whether to operate on local or remote branches.
public enum BranchType: Sendable { case local, remote }
