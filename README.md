# Gitty

A Swift package that wraps [libgit2](https://github.com/ibrahimcetin/libgit2) with an idiomatic, async-first API designed for apps that work with real-world, authenticated repositories.

**Platforms:** iOS 15+ · macOS 12+
**Swift:** 5.9+

## Motivation

Most Git libraries for Apple platforms were built for read-only tooling: browsing history, displaying diffs, inspecting a local repo. Gitty is built for apps that need to act on repositories — authenticate against a remote, commit with a specific author, resolve conflicts, and stream history without loading it all into memory at once.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/RonenMars/Gitty", from: "0.2.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["Gitty"]),
]
```

---

## Real-world walkthrough

### 1 · Clone a private repository

```swift
import Gitty

let repo = try await Repository.clone(
    from: URL(string: "https://github.com/alice/private-app")!,
    to: localURL,
    credentials: .token("ghp_yourPersonalAccessToken"),
    progress: { print("\(Int($0.fractionCompleted * 100))%") }
)
```

### 2 · Stage and commit with a custom author

```swift
let author = Signature(name: "Alice", email: "alice@example.com")

try repo.stage(paths: ["Sources/Login.swift", "README.md"])
// or stage everything: try repo.stageAll()

let commit = try repo.commit(
    message: "feat: add login screen",
    author: author
)
```

### 3 · Push to origin

```swift
try await repo.remotes.push(to: "origin", credentials: .token("ghp_..."))
```

### 4 · Stream commit history

```swift
for try await commit in repo.log(limit: 50) {
    print("\(commit.id.abbreviated)  \(commit.author)  \(commit.subject)")
}
```

### 5 · Diff

```swift
let diffs = try repo.diff()                       // unstaged changes
let diffs = try repo.diff(from: "HEAD")           // working tree vs HEAD
let diffs = try repo.diff(from: commitA, to: commitB)

for diff in diffs {
    print("\(diff.status)  \(diff.newPath ?? "")  (+\(diff.linesAdded) -\(diff.linesDeleted))")
    for hunk in diff.hunks { print(hunk.header) }
}
```

### 6 · Merge

```swift
let feature = try repo.branches.list().first { $0.name == "feature/login" }!

switch try repo.merge(branch: feature) {
case .upToDate:           print("Already up-to-date.")
case .fastForward(let c): print("Fast-forwarded to \(c.id.abbreviated).")
case .merged:             try repo.commit(message: "Merge 'feature/login'", author: author)
case .conflict(let fs):   print("Conflicts: \(fs.map(\.path))")
}
```

### 7 · Rebase

```swift
let main = try repo.branches.list().first { $0.name == "main" }!

switch try repo.rebase(onto: main, author: author) {
case .success(let commits): print("Rebased \(commits.count) commits.")
case .conflict(let files):  print("Resolve: \(files.map(\.path))")
}
```

### 8 · Cherry-pick

```swift
switch try repo.cherryPick(someCommit) {
case .success:
    try repo.commit(message: someCommit.message, author: author)
case .conflict(let files):
    print("Conflicts: \(files.map(\.path))")
}
```

### 9 · Blame

```swift
let hunks = try repo.blame(file: "Sources/App/Login.swift")
for hunk in hunks {
    print("\(hunk.lineRange)  \(hunk.author)  \(hunk.commitID.abbreviated)")
}
```

### 10 · Stash

```swift
try repo.stash.push(message: "WIP", author: author, includeUntracked: true)
let entries = try repo.stash.list()
try repo.stash.pop()    // restore + remove
try repo.stash.apply()  // restore, keep on stack
try repo.stash.drop()   // discard
```

### 11 · Branches

```swift
let branches = try repo.branches.list()
let branch   = try repo.branches.create(named: "feature/x", at: headCommit)
try repo.branches.checkout(branch)
try repo.branches.rename(from: "old", to: "new")
try repo.branches.delete(named: "stale")
```

### 12 · Remotes

```swift
let remotes = try repo.remotes.list()
try repo.remotes.add(name: "upstream", url: "https://github.com/upstream/repo")
try await repo.remotes.fetch(named: "origin", credentials: .token("ghp_..."))
try repo.remotes.remove(named: "old-remote")
```

### 13 · Tags

```swift
let tags = try repo.tags.list()
try repo.tags.create(named: "v1.0.0", at: commit)
try repo.tags.create(named: "v1.0.0", at: commit, message: "Release 1.0.0", tagger: author)
try repo.tags.delete(named: "v0.9.0-beta")
```

### 14 · Worktrees

```swift
let worktrees = try repo.worktreeList()
try repo.addWorktree(name: "hotfix", path: URL(fileURLWithPath: "/tmp/hotfix"), branch: "hotfix/v1")
try repo.removeWorktree(named: "hotfix")
```

---

## API overview

```
Repository
├── static clone(from:to:credentials:progress:)   async throws → Repository
├── static open(at:) / initialize(at:) / exists(at:)
│
├── status(includeUntracked:)                     throws → [StatusEntry]
├── stage(paths:) / stageAll() / unstage(paths:)  throws
├── commit(message:author:)                       throws → Commit
│
├── log(limit:) / log(from:limit:)                → CommitLog (AsyncSequence)
│
├── diff() / diff(from:) / diff(from:to:)         throws → [FileDiff]
│
├── merge(branch:)                                throws → MergeResult
├── rebase(onto:author:) / abortRebase()          throws → RebaseResult
├── cherryPick(_:)                                throws → CherryPickResult
├── blame(file:)                                  throws → [BlameHunk]
│
├── worktreeList() / addWorktree / removeWorktree / lock / unlock
│
├── branches  — list / create / delete / rename / checkout
├── remotes   — list / add / remove / rename / fetch / push
├── tags      — list / create / delete
└── stash     — push / pop / apply / drop / list
```

---

## Credentials

| Case | Use for |
|---|---|
| `.token("ghp_...")` | GitHub / GitLab / Bitbucket PATs over HTTPS |
| `.usernamePassword(username:password:)` | Basic auth or PAT-as-password |
| `.sshAgent` | SSH keys via a running agent |
| `.default` | Public repos / system credential helpers |

---

## Error handling

All operations throw `GittyError` with a `code` (raw libgit2 error code) and a `message`:

```swift
do {
    try await repo.remotes.push(to: "origin", credentials: .token("bad"))
} catch let err as GittyError {
    print("Push failed (\(err.code)): \(err.message)")
}
```

---

## License

MIT
