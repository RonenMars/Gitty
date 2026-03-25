/// Gitty — a Swift libgit2 wrapper with full credentials support.
///
/// ## Quick start
///
/// ```swift
/// import Gitty
///
/// let repo = try await Repository.clone(
///     from: URL(string: "https://github.com/user/private-repo")!,
///     to: URL(fileURLWithPath: "/tmp/my-repo"),
///     credentials: .token("ghp_yourToken"),
///     progress: { print("\(Int($0.fractionCompleted * 100))%") }
/// )
///
/// let author = Signature(name: "Alice", email: "alice@example.com")
/// try repo.stage(paths: ["README.md"])
/// try repo.commit(message: "docs: update readme", author: author)
/// try await repo.remotes.push(to: "origin", credentials: .token("ghp_yourToken"))
///
/// for try await commit in repo.log(limit: 20) {
///     print("\(commit.id.abbreviated)  \(commit.subject)")
/// }
/// ```
public enum Gitty {
    public static let version = "0.2.0"
}
