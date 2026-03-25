/// Authentication credentials for remote git operations (clone, fetch, push).
public enum Credentials: Sendable {

    /// A personal access token (GitHub, GitLab, Bitbucket, etc.).
    /// Sent as `x-access-token:<token>` over HTTPS.
    case token(String)

    /// Plain username and password, or username + PAT for services that require it.
    case usernamePassword(username: String, password: String)

    /// Delegate to the running SSH agent.
    case sshAgent

    /// Let libgit2 fall through to its default credential helpers (public repos).
    case `default`
}
