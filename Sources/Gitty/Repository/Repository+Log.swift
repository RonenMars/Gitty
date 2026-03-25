import libgit2

// MARK: - CommitLog (AsyncSequence)

/// An `AsyncSequence` that lazily walks the commit history.
///
/// ```swift
/// for try await commit in repo.log() {
///     print("\(commit.id.abbreviated)  \(commit.subject)")
/// }
///
/// for try await commit in repo.log(from: "refs/heads/develop", limit: 50) {
///     print(commit.author)
/// }
/// ```
public struct CommitLog: AsyncSequence {
    public typealias Element = Commit

    private let repository: Repository
    private let startRef:   String?
    private let limit:      Int?

    init(repository: Repository, from startRef: String? = nil, limit: Int? = nil) {
        self.repository = repository
        self.startRef   = startRef
        self.limit      = limit
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(repository: repository, from: startRef, limit: limit)
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private let repoPointer: OpaquePointer
        private var walk:        GitPointer?
        private let startRef:    String?
        private let limit:       Int?
        private var count  = 0
        private var ready  = false

        init(repository: Repository, from startRef: String?, limit: Int?) {
            self.repoPointer = repository.pointer
            self.startRef    = startRef
            self.limit       = limit
        }

        public func next() async throws -> Commit? {
            if !ready { try setup(); ready = true }
            guard let walk else { return nil }
            if let limit, count >= limit { return nil }

            var oid    = git_oid()
            let status = git_revwalk_next(&oid, walk.raw)
            if status == GIT_ITEROVER.rawValue { return nil }
            guard status == 0 else { throw GittyError(code: status) }
            count += 1

            var ptr: OpaquePointer?
            guard git_commit_lookup(&ptr, repoPointer, &oid) == 0, let ptr else {
                throw GittyError(message: "Could not look up commit \(oid.hexString)")
            }
            let commitBox = GitPointer.commit(ptr)
            return Commit(pointer: commitBox.raw)
        }

        private func setup() throws {
            var walkPtr: OpaquePointer?
            guard git_revwalk_new(&walkPtr, repoPointer) == 0, let walkPtr else {
                throw GittyError(message: "Could not create revision walker")
            }
            self.walk = .revwalk(walkPtr)
            git_revwalk_sorting(walkPtr, GIT_SORT_TIME.rawValue)

            if let startRef {
                var oid = git_oid()
                if git_reference_name_to_id(&oid, repoPointer, startRef) != 0,
                   git_oid_fromstr(&oid, startRef) != 0 {
                    throw GittyError(message: "Could not resolve log start ref: '\(startRef)'")
                }
                git_revwalk_push(walkPtr, &oid)
            } else {
                let code = git_revwalk_push_head(walkPtr)
                guard code == 0 else { throw GittyError(code: code) }
            }
        }
    }
}

// MARK: - Repository convenience

extension Repository {

    /// Returns a `CommitLog` AsyncSequence starting at HEAD.
    public func log(limit: Int? = nil) -> CommitLog {
        CommitLog(repository: self, from: nil, limit: limit)
    }

    /// Returns a `CommitLog` AsyncSequence starting at the given ref or SHA.
    public func log(from startRef: String, limit: Int? = nil) -> CommitLog {
        CommitLog(repository: self, from: startRef, limit: limit)
    }
}
