import libgit2

/// Namespace for stash operations: `repo.stash.push(...)`, `repo.stash.pop()`, etc.
public struct StashOperations: Sendable {
    let repository: Repository

    // MARK: - Push

    /// Saves current working-tree modifications to a new stash entry.
    @discardableResult
    public func push(
        message: String? = nil,
        author: Signature,
        includeUntracked: Bool = false
    ) throws -> StashEntry {
        let sigPtr = try author.makePointer()
        let sig    = GitPointer.signature(sigPtr)

        var flags: UInt32 = GIT_STASH_DEFAULT.rawValue
        if includeUntracked { flags |= GIT_STASH_INCLUDE_UNTRACKED.rawValue }

        var oid  = git_oid()
        let code = git_stash_save(&oid, repository.pointer, sigPtr, message, flags)
        _ = sig

        if code == GIT_ENOTFOUND.rawValue {
            throw GittyError(message: "No local changes to stash", code: code)
        }
        guard code == 0 else { throw GittyError(code: code) }

        return StashEntry(id: 0, message: message ?? "", commitID: OID(raw: oid))
    }

    // MARK: - Pop

    /// Restores the stash entry at `index` and removes it from the stack.
    public func pop(index: Int = 0) throws {
        var opts = git_stash_apply_options()
        git_stash_apply_init_options(&opts, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))
        let code = git_stash_pop(repository.pointer, index, &opts)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Apply

    /// Applies the stash entry at `index` without removing it.
    public func apply(index: Int = 0) throws {
        var opts = git_stash_apply_options()
        git_stash_apply_init_options(&opts, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))
        let code = git_stash_apply(repository.pointer, index, &opts)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Drop

    /// Drops the stash entry at `index` without applying it.
    public func drop(index: Int = 0) throws {
        let code = git_stash_drop(repository.pointer, index)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - List

    /// Returns all stash entries, newest first.
    public func list() throws -> [StashEntry] {
        let box = StashListBox()
        withExtendedLifetime(box) {
            git_stash_foreach(repository.pointer, { index, msgPtr, oidPtr, payload in
                guard let payload else { return 0 }
                let box = Unmanaged<StashListBox>.fromOpaque(payload).takeUnretainedValue()
                let msg = msgPtr.map { String(cString: $0) } ?? ""
                let oid = oidPtr.map { OID(raw: $0.pointee) } ?? OID(string: String(repeating: "0", count: 40))!
                box.entries.append(StashEntry(id: Int(index), message: msg, commitID: oid))
                return 0
            }, Unmanaged.passUnretained(box).toOpaque())
        }
        return box.entries
    }
}
