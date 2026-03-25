import XCTest
@testable import Gitty

final class BranchTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyBranchTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    /// Seeds the repo with one commit and returns it.
    private func seed(_ repo: Repository, dir: URL) throws -> Commit {
        try write("seed", to: "seed.txt", in: dir)
        try repo.stage(paths: ["seed.txt"])
        return try repo.commit(message: "seed", author: author)
    }

    func testListLocalBranches() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            _ = try repo.branches.create(named: "feature", at: commit)
            let names = try repo.branches.list().map(\.name)
            XCTAssertTrue(names.contains("feature"))
        }
    }

    func testCreateBranch() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            let branch = try repo.branches.create(named: "new-branch", at: commit)
            XCTAssertEqual(branch.name, "new-branch")
            XCTAssertEqual(branch.tipID, commit.id)
        }
    }

    func testDeleteBranch() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            _ = try repo.branches.create(named: "to-delete", at: commit)
            try repo.branches.delete(named: "to-delete")
            let names = try repo.branches.list().map(\.name)
            XCTAssertFalse(names.contains("to-delete"))
        }
    }

    func testRenameBranch() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            _ = try repo.branches.create(named: "old-name", at: commit)
            let renamed = try repo.branches.rename(from: "old-name", to: "new-name")
            XCTAssertEqual(renamed.name, "new-name")
            let names = try repo.branches.list().map(\.name)
            XCTAssertTrue(names.contains("new-name"))
            XCTAssertFalse(names.contains("old-name"))
        }
    }

    func testCheckoutBranch() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            let branches = try repo.branches.list()
            guard let main = branches.first else { return XCTFail("No branches") }
            let feature = try repo.branches.create(named: "feature", at: commit)

            try repo.branches.checkout(feature)

            // Add a commit on feature, then switch back to main
            try write("b", to: "b.txt", in: dir)
            try repo.stage(paths: ["b.txt"])
            try repo.commit(message: "feature commit", author: author)

            try repo.branches.checkout(main)
            XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("b.txt").path))
        }
    }
}
