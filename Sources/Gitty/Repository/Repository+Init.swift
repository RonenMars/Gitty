import Foundation
import libgit2

extension Repository {

    // MARK: - Open

    /// Opens an existing git repository at the given path.
    public static func open(at url: URL) throws -> Repository {
        GitRuntime.initialize()
        var ptr: OpaquePointer?
        let code = git_repository_open(&ptr, url.path)
        guard code == 0, let ptr else { throw GittyError(code: code) }
        let workDir = git_repository_workdir(ptr)
            .map { URL(fileURLWithPath: String(cString: $0)) } ?? url
        return Repository(pointer: ptr, workingDirectory: workDir)
    }

    /// Returns `true` if the given directory is a git repository.
    public static func exists(at url: URL) -> Bool {
        GitRuntime.initialize()
        var ptr: OpaquePointer?
        let ok = git_repository_open(&ptr, url.path) == 0
        if let ptr { git_repository_free(ptr) }
        return ok
    }

    // MARK: - Initialize

    /// Creates a new git repository at the given path.
    @discardableResult
    public static func initialize(at url: URL, bare: Bool = false) throws -> Repository {
        GitRuntime.initialize()
        var ptr: OpaquePointer?
        let code = git_repository_init(&ptr, url.path, bare ? 1 : 0)
        guard code == 0, let ptr else { throw GittyError(code: code) }
        let workDir = git_repository_workdir(ptr)
            .map { URL(fileURLWithPath: String(cString: $0)) } ?? url
        return Repository(pointer: ptr, workingDirectory: workDir)
    }

    // MARK: - Clone

    /// Clones a remote repository to a local path.
    ///
    /// ```swift
    /// let repo = try await Repository.clone(
    ///     from: URL(string: "https://github.com/user/repo")!,
    ///     to: URL(fileURLWithPath: "/tmp/repo"),
    ///     credentials: .token("ghp_..."),
    ///     progress: { print("\(Int($0.fractionCompleted * 100))%") }
    /// )
    /// ```
    public static func clone(
        from remoteURL: URL,
        to localURL: URL,
        credentials: Credentials = .default,
        progress: ((TransferProgress) -> Void)? = nil
    ) async throws -> Repository {
        GitRuntime.initialize()

        return try await Task.detached(priority: .userInitiated) {
            var options = git_clone_options()
            git_clone_init_options(&options, UInt32(GIT_CLONE_OPTIONS_VERSION))
            options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

            let ctx    = CloneContext(credentials: credentials, progressHandler: progress)
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
            defer { Unmanaged<CloneContext>.fromOpaque(ctxPtr).release() }

            options.fetch_opts.callbacks.credentials       = cloneCredentialCallback
            options.fetch_opts.callbacks.transfer_progress = cloneTransferProgressCallback
            options.fetch_opts.callbacks.payload           = ctxPtr

            var ptr: OpaquePointer?
            let code = git_clone(&ptr, remoteURL.absoluteString, localURL.path, &options)
            guard code == 0, let ptr else { throw GittyError(code: code) }

            let workDir = git_repository_workdir(ptr)
                .map { URL(fileURLWithPath: String(cString: $0)) } ?? localURL
            return Repository(pointer: ptr, workingDirectory: workDir)
        }.value
    }
}
