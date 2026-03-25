# Gitty — CLAUDE.md

> Swift libgit2 wrapper · Modern, async-first, SPM-native Git library for iOS & macOS
> Repo: https://github.com/RonenMars/Gitty

---

## What this file is

This is the authoritative implementation guide for Claude Code working on Gitty.
Read it fully before touching any file. Every section is load-bearing.

---

## Dependency

Gitty depends on **`RonenMars/libgit2`** — a fork of the official
`libgit2/libgit2` C library with two files added for SPM support:

- `Package.swift` — SPM manifest exposing the C sources as a Swift target
- `src/util/git2_features.h` — manually-generated replacement for the
  CMake-generated feature header (zero system deps: builtin SHA1, SHA256,
  zlib, HTTP parser, regex; pthreads; no HTTPS; no SSH)

`Gitty/Package.swift` already points to this fork:
```swift
.package(url: "https://github.com/RonenMars/libgit2", from: "1.9.0"),
```

**Do not change this dependency.** Do not reference `ibrahimcetin/libgit2`
anywhere. The dependency chain is:

```
Your app → Gitty → RonenMars/libgit2 (fork of libgit2/libgit2)
```

---

## Current state (read before writing a single line)

### What exists and works

All 36 Swift source files are real, non-trivial implementations — **not stubs**.

| Area | Files | Status |
|---|---|---|
| Core infra | `GittyError`, `GitRuntime`, `Pointer`, `CallbackContexts`, `libgit2+Extensions` | ✅ Complete |
| Models | `OID`, `Commit`, `Signature`, `Branch`, `Remote`, `Tag`, `StatusEntry`, `FileDiff`, `MergeResult`, `ConflictedFile`, `StashEntry`, `BlameHunk`, `TransferProgress` | ✅ Complete |
| Repository | open, initialize, exists, clone (async, credentials, progress) | ✅ Complete |
| Stage/Commit | `stage(paths:)`, `stageAll()`, `unstage(paths:)`, `commit(message:author:)` | ✅ Complete |
| Status | `status(includeUntracked:)` → `[StatusEntry]` | ✅ Complete |
| Log | `CommitLog` AsyncSequence, `log(limit:)`, `log(from:limit:)` | ✅ Complete |
| Diff | `diff()`, `diff(from:)`, `diff(from:to:)` — typed hunks + lines | ✅ Complete |
| Merge | `merge(branch:)` → `MergeResult` (upToDate/fastForward/merged/conflict) | ✅ Complete |
| Rebase | `rebase(onto:author:)`, `abortRebase()` → `RebaseResult` | ✅ Complete |
| CherryPick | `cherryPick(_:)` → `CherryPickResult` | ✅ Complete |
| Blame | `blame(file:)` → `[BlameHunk]` | ✅ Complete |
| Worktrees | `worktreeList()`, `addWorktree`, `removeWorktree`, `lockWorktree`, `unlockWorktree` | ✅ Complete |
| Branches | `list`, `create`, `delete`, `rename`, `checkout` | ✅ Complete |
| Remotes | `list`, `add`, `remove`, `rename`, `fetch` (async), `push` (async) | ✅ Complete |
| Tags | `list`, `create` (lightweight + annotated), `delete` | ✅ Complete |
| Stash | `push`, `pop`, `apply`, `drop`, `list` | ✅ Complete |
| Credentials | `.token`, `.usernamePassword`, `.sshAgent`, `.default` | ✅ Complete |
| Dependency | `Package.swift` → `RonenMars/libgit2` from `1.9.0` | ✅ Done |
| Tests | RepositoryTests, MergeTests, DiffTests, BlameTests, StashTests | ✅ Passing |

### What is NOT done yet

| Gap | Detail |
|---|---|
| **`swift build` verification** | `swift build` must be run after dep swap to confirm `RonenMars/libgit2` compiles cleanly — this is the first thing Phase 1 does |
| **Config API** | `repository.config.get/set` not implemented |
| **Submodules** | Not implemented |
| **CI** | No `.github/workflows/swift.yml` |
| **`RebaseResult` location** | Defined inline in `Repository+Rebase.swift`, should live in `Models/` |
| **`unstage` cleanup** | Has dead `buf` variable and overly complex nested logic |
| **Linux** | Not in platforms, untested |
| **Release tag** | Swift Package Index requires a tagged release |

---

## Architecture — never deviate from these patterns

### The `GitPointer` pattern (mandatory for all libgit2 resources)

Every `OpaquePointer` from libgit2 **must** be wrapped in `GitPointer`
immediately after creation. Never use raw `defer { git_X_free(ptr) }`.

```swift
// ✅ Correct
var ptr: OpaquePointer?
let code = git_commit_lookup(&ptr, repo, &oid)
guard code == 0, let ptr else { throw GittyError(code: code) }
let commit = GitPointer.commit(ptr)  // freed automatically on deinit

// ❌ Never do this
var ptr: OpaquePointer?
git_commit_lookup(&ptr, repo, &oid)
defer { git_commit_free(ptr) }
```

All `GitPointer` factory methods live in `Internal/Pointer.swift`.
Add new ones there if a new libgit2 type is introduced.

### Error handling (always consistent)

```swift
let code = git_some_operation(...)
guard code == 0 else { throw GittyError(code: code) }
// GittyError(code:) reads git_error_last() automatically

// Only use GittyError(message:) for logic errors with no libgit2 code:
throw GittyError(message: "Branch '\(name)' not found")
```

### Async — only for network operations

`clone`, `fetch`, `push` are `async throws` and use
`Task.detached(priority: .userInitiated)`. Everything else is synchronous
`throws`. Do not make anything else async.

### Namespace sub-objects

```swift
repo.branches.create(named: "feature", at: commit)
repo.remotes.push(to: "origin", credentials: .token("..."))
repo.stash.push(message: "WIP", author: author)
repo.tags.list()
repo.config.get("user.name")      // Phase 2
repo.submodules.list()            // Phase 2
```

### File naming conventions

| Type | Location |
|---|---|
| Repository extensions | `Sources/Gitty/Repository/Repository+Feature.swift` |
| Namespace operations | `Sources/Gitty/Operations/FeatureOperations.swift` |
| Models | `Sources/Gitty/Models/FeatureModel.swift` (one type per file) |
| Internal helpers | `Sources/Gitty/Internal/` |

### Sendable rules

- All public types: `Sendable`
- `Repository` only: `@unchecked Sendable` (wraps `OpaquePointer`)
- Value types (structs/enums): never `@unchecked Sendable`

---

## MCP servers — when and how to use each

### `sequential-thinking`
Use at the **start of any non-trivial task** before touching files.
Best for: multi-file tasks, debugging unexpected libgit2 return codes,
designing a new API before implementing it.

### `swift-lsp`
Use **before every `swift build`** to catch type errors early.
Also use to: find all callers before renaming/removing, check if a
libgit2 function signature exists in the current version.

### `context7`
Use when implementing any new libgit2 operation to check the exact
function signature, flags, return codes, and memory ownership rules.
Query examples: `"libgit2 git_config_get_string"`,
`"libgit2 git_submodule_foreach callback"`.

### `github` MCP
Use for: reading `RonenMars/libgit2` or `RonenMars/Gitty` files without
cloning, creating PRs for completed phases, verifying file SHAs.

### `octocode`
Use for: finding reference implementations of specific libgit2 operations
in other Swift packages. Never copy — only compare.

### `task-master-ai`
Session start ritual:
```
task-master-ai: parse this CLAUDE.md → create tasks
task-master-ai: next_task → begin
```
Mark tasks complete after each phase. Use `update_subtask` to log
blockers or notes mid-phase.

### `serena`
Use for semantic search: "find all usages of `GitPointer.commit`",
"find all places that throw `GittyError`". Essential before refactoring
any internal type.

### `commit-commands`
Use after each logical unit. Runs `swift build && swift test` before
committing. Commit message format: `type(scope): description`.
Examples: `feat(config): add config get/set`, `fix(rebase): handle GIT_EAPPLIED`.

### `ralph-wiggum` / `superpowers`
Use for: generating test fixtures (bare repos, repos with specific history
shapes), running the real `git` CLI to verify expected behavior before
implementing it in Swift, diffing CLI output vs Gitty output.

---

## Agent teams — when to use parallel agents

Use **team leader + sub-agents** only when tasks have non-overlapping
file ownership. Never parallelize when tasks share a file.

### Phase 2 is the right candidate

Phase 2 has three fully independent streams:

| Agent | Files owned |
|---|---|
| **Agent A — Config** | `Models/Config.swift`, `Operations/ConfigOperations.swift`, `Repository+Config.swift`, `ConfigTests.swift` |
| **Agent B — Submodules** | `Models/Submodule.swift`, `Operations/SubmoduleOperations.swift`, `Repository+Submodule.swift`, `SubmoduleTests.swift` |
| **Agent C — CI** | `.github/workflows/swift.yml`, `Gitty.swift` version bump |

Team leader workflow:
1. Assign streams, provide this CLAUDE.md to each agent
2. Each agent reports back with `swift build && swift test` green
3. Leader reviews diffs, merges all three in one phase commit

### Do NOT parallelize
- Phase 1 (build verification + housekeeping) — serial, touches shared files
- Test coverage work in Phase 1 — each test file depends on stable implementation

---

## Implementation phases

### Phase 1 — Build verification + housekeeping ⚠️ Start here

**Step 1a — Verify the build with `RonenMars/libgit2` (do this first)**

```bash
swift package update
swift build
swift test
```

`swift build` compiles all libgit2 C sources for the first time via SPM.
It may take 1–2 minutes. If errors appear they will fall into these categories:

| Error type | Symptom | Fix |
|---|---|---|
| Missing header | `'somefile.h' file not found` | Add directory to `headerSearchPath` in `RonenMars/libgit2` `Package.swift` |
| Undeclared identifier | `use of undeclared identifier 'GIT_X'` | Add `#define GIT_X 1` to `RonenMars/libgit2` `src/util/git2_features.h` |
| Duplicate symbol | `error: duplicate symbol '_func'` | Add the offending `.c` file to `exclude` in `RonenMars/libgit2` `Package.swift` |
| Compiler warning as error | `-Wno-*` needed | Add flag to `unsafeFlags` in `RonenMars/libgit2` `Package.swift` |

To fix errors in `RonenMars/libgit2`, edit locally, push to GitHub, then
`swift package update` in Gitty to pick up the change.

**Exit criteria for 1a:** `swift build && swift test` — zero errors.
**Commit:** `chore(deps): verify RonenMars/libgit2 builds cleanly`

---

**Step 1b — Extract `RebaseResult` to `Models/`**

- Create `Sources/Gitty/Models/RebaseResult.swift`
- Move `RebaseResult` enum out of `Repository+Rebase.swift`
- Leave `CherryPickResult` in `Repository+CherryPick.swift` (fine where it is)
- **Commit:** `refactor(models): extract RebaseResult to Models/`

---

**Step 1c — Simplify `unstage`**

Current `unstage(paths:)` in `Repository+Stage.swift` has a dead `buf`
variable and redundant nested logic. Simplify to:

```swift
// When HEAD exists: reset index entry to HEAD state via git_reset_default
// When no HEAD (initial repo): remove from index with git_index_remove_bypath
```

Add `testUnstage` to `RepositoryTests.swift`.
**MCP:** `sequential-thinking` before touching this.
**Commit:** `fix(stage): simplify unstage, add test`

---

**Step 1d — Expand test coverage**

Current tests cover: repository init/open, stage/commit, status, OID,
branches (basic), merge, diff, blame, stash. Add:

| File to create | Key scenarios |
|---|---|
| `BranchTests.swift` | create, list local+remote, delete, rename, checkout |
| `TagTests.swift` | lightweight create, annotated create, list, delete |
| `RemoteTests.swift` | add, remove, rename, list (use local bare repo — no network) |
| `WorktreeTests.swift` | add, list, remove, lock, unlock |
| `RebaseTests.swift` | clean rebase, conflict detection and abort |
| `CherryPickTests.swift` | clean pick, conflict pick |
| `LogTests.swift` | AsyncSequence iteration, `from:` ref, `limit:` cap |

**Testing pattern — copy from `RepositoryTests.swift` exactly:**

```swift
final class BranchTests: XCTestCase {

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try body(tmp)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")
}
```

Key patterns:
- Always use `Repository.initialize(at:)` — never clone from network
- For remote tests: `Repository.initialize(at: bareDir, bare: true)`,
  then `repo.remotes.add(name: "origin", url: bareDir.path)`
- For conflict tests: two branches that modify the same line of the same file

**MCP:** `ralph-wiggum` for complex fixture repos, `sequential-thinking`
before conflict setups, `swift-lsp` throughout.

**Phase 1 exit criteria:** `swift test` ≥ 40 test cases, all green, no warnings.

---

### Phase 2 — Config + Submodules + CI (parallel agents)

#### Stream A — Config API

**Files:**
- `Sources/Gitty/Models/Config.swift`
- `Sources/Gitty/Operations/ConfigOperations.swift`
- `Sources/Gitty/Repository/Repository+Config.swift`
- `Tests/GittyTests/ConfigTests.swift`

**Public API:**
```swift
// Add to Repository.swift:
public var config: ConfigOperations { ConfigOperations(repository: self) }

// Usage:
let name = try repo.config.get("user.name")           // → String?
try repo.config.set("user.name", value: "Alice")
try repo.config.set("core.autocrlf", boolValue: false)
let all  = try repo.config.list()                     // → [ConfigEntry]
try repo.config.delete("some.key")
```

**Model:**
```swift
public struct ConfigEntry: Sendable, Identifiable {
    public var id: String { key }
    public let key:   String
    public let value: String
}
```

**libgit2 functions:**
`git_repository_config`, `git_config_get_string`, `git_config_set_string`,
`git_config_set_bool`, `git_config_delete_entry`, `git_config_foreach`

---

#### Stream B — Submodules

**Files:**
- `Sources/Gitty/Models/Submodule.swift`
- `Sources/Gitty/Operations/SubmoduleOperations.swift`
- `Sources/Gitty/Repository/Repository+Submodule.swift`
- `Tests/GittyTests/SubmoduleTests.swift`

**Public API:**
```swift
// Add to Repository.swift:
public var submodules: SubmoduleOperations { SubmoduleOperations(repository: self) }

// Usage:
let subs = try repo.submodules.list()
try repo.submodules.initialize(named: "vendor/lib")
try repo.submodules.update(named: "vendor/lib")
```

**Model:**
```swift
public struct Submodule: Sendable, Identifiable {
    public var id: String { name }
    public let name:   String
    public let path:   String
    public let url:    String
    public let headID: OID?
}
```

**libgit2 functions:**
`git_submodule_foreach`, `git_submodule_update`, `git_submodule_init`,
`git_submodule_lookup`, `git_submodule_name`, `git_submodule_path`,
`git_submodule_url`, `git_submodule_head_id`

---

#### Stream C — CI

**Create `.github/workflows/swift.yml`:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  build-macos:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift build -c release
      - run: swift test

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: "5.9"
      - run: swift build
      - run: swift test
```

**Update `Gitty.swift`:**
```swift
public static let version = "0.3.0"
```

**Phase 2 exit criteria:** CI green on macOS and Linux.
`swift test` ≥ 50 test cases. All three streams merged.

---

### Phase 3 — Release v0.1.0

**Steps (serial, in order):**

1. `swift test` — must be 100% green
2. `swift build -c release` — must succeed
3. Confirm `Package.swift` uses `RonenMars/libgit2 from: "1.9.0"`
4. Update `README.md` installation block to `from: "0.1.0"`
5. Update `Gitty.swift`: `version = "0.1.0"`
6. Tag and push:
   ```bash
   git tag -a v0.1.0 -m "Initial public release"
   git push origin main --tags
   ```
7. Submit to Swift Package Index: https://swiftpackageindex.com/add-a-package
8. Add GitHub repo topics (Settings → Topics):
   `swift`, `git`, `libgit2`, `spm`, `swift-package-manager`, `ios`, `macos`, `git-client`
9. Post to Swift Forums → Community Showcase

---

## Updating `RonenMars/libgit2`

If `swift build` fails due to a libgit2 C compilation error:

1. Clone `RonenMars/libgit2` locally (or edit via GitHub web UI)
2. Fix `Package.swift` or `src/util/git2_features.h` as needed
3. Push to `RonenMars/libgit2` main
4. Back in Gitty: `swift package update` to fetch the fix
5. Re-run `swift build`

When libgit2 upstream releases a new version and you want to sync:
```bash
cd RonenMars/libgit2
git remote add upstream https://github.com/libgit2/libgit2.git
git fetch upstream
git merge upstream/main --no-edit
# Re-check Package.swift and git2_features.h for any new source dirs or defines
git tag <new-version>
git push origin main --tags
```
Then update `Gitty/Package.swift` to `from: "<new-version>"`.

---

## Code templates — copy exactly

### New repository extension
```swift
// Sources/Gitty/Repository/Repository+Feature.swift
import libgit2

extension Repository {
    public func featureOperation(param: SomeType) throws -> ReturnType {
        // 1. Validate inputs — throw GittyError(message:) for logic errors
        // 2. Acquire libgit2 resources — immediately wrap in GitPointer
        var ptr: OpaquePointer?
        let code = git_something(&ptr, pointer, param.rawValue)
        guard code == 0, let ptr else { throw GittyError(code: code) }
        let box = GitPointer.something(ptr)
        // 3. Build Swift model from C data and return
        return ReturnType(pointer: box.raw)
    }
}
```

### New namespace operations struct
```swift
// Sources/Gitty/Operations/FeatureOperations.swift
import libgit2

public struct FeatureOperations: Sendable {
    let repository: Repository

    public func list() throws -> [FeatureModel] { ... }

    @discardableResult
    public func create(named name: String) throws -> FeatureModel { ... }

    public func delete(named name: String) throws { ... }
}
```

Then add to `Repository.swift`:
```swift
public var feature: FeatureOperations { FeatureOperations(repository: self) }
```

### New model
```swift
// Sources/Gitty/Models/Feature.swift
public struct Feature: Sendable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String

    // No public init — constructed internally only
    init(pointer: OpaquePointer) {
        self.name = git_feature_name(pointer).map { String(cString: $0) } ?? ""
    }
}
```

---

## Hard rules — never violate

- **Never** use `defer { git_X_free(ptr) }` — always `GitPointer`
- **Never** make synchronous git operations `async`
- **Never** expose `OpaquePointer` or any libgit2 C type in public API
- **Never** copy from SwiftGitX source — clean-room implementation only
- **Never** add external dependencies beyond `libgit2`
- **Never** reference `ibrahimcetin/libgit2` — the dependency is `RonenMars/libgit2`
- **Never** use `try!` or `!` force-unwraps outside tests
- **Never** add `@unchecked Sendable` to value types
- **Never** commit when `swift test` is failing

---

## Session rituals

**Start of every session:**
```
1. task-master-ai: get_tasks               → see current phase/status
2. sequential-thinking: plan today's work
3. swift-lsp: check current diagnostics
4. swift build && swift test               → confirm green baseline
```

**End of every session:**
```
1. swift build -c release                  → must be green
2. swift test                              → must be green
3. commit-commands: commit with type(scope): message
4. task-master-ai: set_task_status         → mark completed items
```

---

## libgit2 API reference

Full C API docs: https://libgit2.org/libgit2/#HEAD

Sections relevant to remaining work:
- Config: https://libgit2.org/libgit2/#HEAD/group/config
- Submodules: https://libgit2.org/libgit2/#HEAD/group/submodule

Use `context7` MCP to pull these inline during implementation.
