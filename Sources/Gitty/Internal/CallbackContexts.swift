import libgit2

// MARK: - Clone context (credentials + progress)

final class CloneContext {
    let credentials: Credentials
    var credentialCallCount = 0
    let progressHandler: ((TransferProgress) -> Void)?

    init(credentials: Credentials, progressHandler: ((TransferProgress) -> Void)?) {
        self.credentials     = credentials
        self.progressHandler = progressHandler
    }
}

let cloneCredentialCallback: git_credential_acquire_cb = { out, _, usernamePtr, _, payload in
    guard let payload else { return GIT_EAUTH.rawValue }
    let ctx = Unmanaged<CloneContext>.fromOpaque(payload).takeUnretainedValue()
    ctx.credentialCallCount += 1
    guard ctx.credentialCallCount <= 1 else { return GIT_EAUTH.rawValue }
    return resolveCredential(out: out, username: usernamePtr, credentials: ctx.credentials)
}

let cloneTransferProgressCallback: git_indexer_progress_cb = { statsPtr, payload in
    guard Task.isCancelled == false else { return 1 }
    guard let statsPtr, let payload else { return 0 }
    let ctx = Unmanaged<CloneContext>.fromOpaque(payload).takeUnretainedValue()
    ctx.progressHandler?(TransferProgress(raw: statsPtr.pointee))
    return 0
}

// MARK: - Push / fetch context

final class RemoteCallbackContext {
    let credentials: Credentials
    var callCount = 0

    init(credentials: Credentials) { self.credentials = credentials }
}

let remoteCredentialCallback: git_credential_acquire_cb = { out, _, usernamePtr, _, payload in
    guard let payload else { return GIT_EAUTH.rawValue }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    ctx.callCount += 1
    guard ctx.callCount <= 1 else { return GIT_EAUTH.rawValue }
    return resolveCredential(out: out, username: usernamePtr, credentials: ctx.credentials)
}

// MARK: - Shared resolver

private func resolveCredential(
    out: UnsafeMutablePointer<UnsafeMutablePointer<git_credential>?>?,
    username: UnsafePointer<CChar>?,
    credentials: Credentials
) -> Int32 {
    switch credentials {
    case .token(let t):
        return git_credential_userpass_plaintext_new(out, "x-access-token", t)
    case .usernamePassword(let u, let p):
        return git_credential_userpass_plaintext_new(out, u, p)
    case .sshAgent:
        let u = username.map { String(cString: $0) } ?? "git"
        return git_credential_ssh_key_from_agent(out, u)
    case .default:
        return GIT_PASSTHROUGH.rawValue
    }
}

// MARK: - Stash list box

final class StashListBox {
    var entries: [StashEntry] = []
}
