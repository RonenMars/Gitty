import Foundation
import libgit2

/// A handle to a git repository.
public final class Repository: @unchecked Sendable {

    // MARK: - Properties

    let pointer: OpaquePointer

    /// The working directory of the repository (not the `.git` folder).
    public let workingDirectory: URL

    // MARK: - Init / deinit

    init(pointer: OpaquePointer, workingDirectory: URL) {
        self.pointer          = pointer
        self.workingDirectory = workingDirectory
    }

    deinit { git_repository_free(pointer) }

    // MARK: - HEAD

    /// The name of the currently checked-out branch, or `nil` if HEAD is detached.
    public var currentBranch: String? {
        var ref: OpaquePointer?
        guard git_repository_head(&ref, pointer) == 0, let ref else { return nil }
        let p = GitPointer.reference(ref)
        guard git_reference_is_branch(p.raw) != 0 else { return nil }
        var name: UnsafePointer<CChar>?
        guard git_branch_name(&name, p.raw) == 0, let name else { return nil }
        return String(cString: name)
    }

    // MARK: - Namespace accessors

    /// Access stash operations.
    public var stash: StashOperations { StashOperations(repository: self) }

    /// Access branch operations.
    public var branches: BranchOperations { BranchOperations(repository: self) }

    /// Access remote operations.
    public var remotes: RemoteOperations { RemoteOperations(repository: self) }

    /// Access tag operations.
    public var tags: TagOperations { TagOperations(repository: self) }
}
