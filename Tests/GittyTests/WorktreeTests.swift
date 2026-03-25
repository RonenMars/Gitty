import XCTest
@testable import Gitty

final class WorktreeTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyWorktreeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    private func seed(_ repo: Repository, dir: URL) throws {
        try write("seed", to: "seed.txt", in: dir)
        try repo.stage(paths: ["seed.txt"])
        try repo.commit(message: "seed", author: author)
    }

    /// Returns a unique path that does NOT yet exist on disk.
    /// libgit2's git_worktree_add creates the directory itself.
    private func freshWorktreePath(prefix: String = "wt") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    }

    func testAddAndListWorktree() throws {
        try withRepo { dir, repo in
            try seed(repo, dir: dir)
            let wtDir = freshWorktreePath()
            defer { try? FileManager.default.removeItem(at: wtDir) }

            let wt = try repo.addWorktree(name: "linked", path: wtDir)
            XCTAssertEqual(wt.name, "linked")

            let list = try repo.worktreeList()
            XCTAssertTrue(list.contains { $0.name == "linked" })
        }
    }

    func testLockAndUnlockWorktree() throws {
        try withRepo { dir, repo in
            try seed(repo, dir: dir)
            let wtDir = freshWorktreePath(prefix: "wt-lock")
            defer { try? FileManager.default.removeItem(at: wtDir) }

            _ = try repo.addWorktree(name: "lockable", path: wtDir)

            XCTAssertNoThrow(try repo.lockWorktree(named: "lockable", reason: "testing"))

            let locked = try repo.worktreeList().first { $0.name == "lockable" }
            XCTAssertEqual(locked?.isLocked, true)

            XCTAssertNoThrow(try repo.unlockWorktree(named: "lockable"))

            let unlocked = try repo.worktreeList().first { $0.name == "lockable" }
            XCTAssertEqual(unlocked?.isLocked, false)
        }
    }

    func testRemoveWorktree() throws {
        try withRepo { dir, repo in
            try seed(repo, dir: dir)
            let wtDir = freshWorktreePath(prefix: "wt-rm")

            _ = try repo.addWorktree(name: "removable", path: wtDir)
            // Remove the on-disk directory so prune considers it gone
            try FileManager.default.removeItem(at: wtDir)

            XCTAssertNoThrow(try repo.removeWorktree(named: "removable"))

            let list = try repo.worktreeList()
            XCTAssertFalse(list.contains { $0.name == "removable" })
        }
    }
}
