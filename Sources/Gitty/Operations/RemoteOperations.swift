import libgit2

/// Namespace for remote operations: `repo.remotes.list()`, `repo.remotes.add(...)`, etc.
public struct RemoteOperations: Sendable {
    let repository: Repository

    // MARK: - List

    /// Returns all configured remotes.
    public func list() throws -> [Remote] {
        var names = git_strarray()
        let code  = git_remote_list(&names, repository.pointer)
        guard code == 0 else { throw GittyError(code: code) }
        defer { git_strarray_free(&names) }

        var result: [Remote] = []
        for i in 0..<names.count {
            guard let nameCStr = names.strings?[i] else { continue }
            var remotePtr: OpaquePointer?
            guard git_remote_lookup(&remotePtr, repository.pointer, nameCStr) == 0,
                  let remotePtr else { continue }
            let box = GitPointer.remote(remotePtr)
            if let remote = Remote(pointer: box.raw) { result.append(remote) }
        }
        return result
    }

    // MARK: - Add

    /// Adds a new remote named `name` pointing at `url`.
    @discardableResult
    public func add(name: String, url: String) throws -> Remote {
        var remotePtr: OpaquePointer?
        let code = git_remote_create(&remotePtr, repository.pointer, name, url)
        guard code == 0, let remotePtr else { throw GittyError(code: code) }
        let box = GitPointer.remote(remotePtr)
        guard let remote = Remote(pointer: box.raw) else {
            throw GittyError(message: "Could not read newly created remote '\(name)'")
        }
        return remote
    }

    // MARK: - Remove

    /// Removes the remote named `name` and all associated configuration.
    public func remove(named name: String) throws {
        let code = git_remote_delete(repository.pointer, name)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Rename

    /// Renames a remote from `oldName` to `newName`.
    public func rename(from oldName: String, to newName: String) throws {
        var problems = git_strarray()
        let code = git_remote_rename(&problems, repository.pointer, oldName, newName)
        git_strarray_free(&problems)
        guard code == 0 else { throw GittyError(code: code) }
    }

    // MARK: - Fetch

    /// Fetches from the remote named `name`.
    public func fetch(named name: String, credentials: Credentials) async throws {
        let repo = repository

        try await Task.detached(priority: .userInitiated) {
            var remotePtr: OpaquePointer?
            guard git_remote_lookup(&remotePtr, repo.pointer, name) == 0, let remotePtr else {
                throw GittyError(message: "Remote '\(name)' not found")
            }
            let box = GitPointer.remote(remotePtr)

            let ctx    = RemoteCallbackContext(credentials: credentials)
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
            defer { Unmanaged<RemoteCallbackContext>.fromOpaque(ctxPtr).release() }

            var callbacks = git_remote_callbacks()
            git_remote_init_callbacks(&callbacks, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
            callbacks.credentials = remoteCredentialCallback
            callbacks.payload     = ctxPtr

            var fetchOpts = git_fetch_options()
            git_fetch_init_options(&fetchOpts, UInt32(GIT_FETCH_OPTIONS_VERSION))
            fetchOpts.callbacks = callbacks

            let code = git_remote_fetch(box.raw, nil, &fetchOpts, nil)
            guard code == 0 else { throw GittyError(code: code) }
        }.value
    }

    // MARK: - Push

    /// Pushes the current branch to the remote named `name`.
    public func push(to name: String, credentials: Credentials) async throws {
        let repo = repository

        try await Task.detached(priority: .userInitiated) {
            var remotePtr: OpaquePointer?
            guard git_remote_lookup(&remotePtr, repo.pointer, name) == 0, let remotePtr else {
                throw GittyError(message: "Remote '\(name)' not found")
            }
            let box = GitPointer.remote(remotePtr)

            var headRef: OpaquePointer?
            guard git_repository_head(&headRef, repo.pointer) == 0, let headRef else {
                throw GittyError(message: "Could not determine current branch")
            }
            let hr = GitPointer.reference(headRef)

            var branchName: UnsafePointer<CChar>?
            guard git_branch_name(&branchName, hr.raw) == 0, let branchName else {
                throw GittyError(message: "Could not read branch name")
            }
            let branch  = String(cString: branchName)
            let refspec = "refs/heads/\(branch):refs/heads/\(branch)"

            let ctx    = RemoteCallbackContext(credentials: credentials)
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
            defer { Unmanaged<RemoteCallbackContext>.fromOpaque(ctxPtr).release() }

            var callbacks = git_remote_callbacks()
            git_remote_init_callbacks(&callbacks, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
            callbacks.credentials = remoteCredentialCallback
            callbacks.payload     = ctxPtr

            var pushOpts = git_push_options()
            git_push_init_options(&pushOpts, UInt32(GIT_PUSH_OPTIONS_VERSION))
            pushOpts.callbacks = callbacks

            let code: Int32 = refspec.withCString { cStr in
                var mutableCStr: UnsafeMutablePointer<CChar>? = UnsafeMutablePointer(mutating: cStr)
                return withUnsafeMutablePointer(to: &mutableCStr) { ptrPtr in
                    var strArray = git_strarray(strings: ptrPtr, count: 1)
                    return git_remote_push(box.raw, &strArray, &pushOpts)
                }
            }
            guard code == 0 else { throw GittyError(code: code) }
        }.value
    }
}
