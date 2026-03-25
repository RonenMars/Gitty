import XCTest
@testable import Gitty

final class RepositoryTests: XCTestCase {

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try body(tmp)
    }

    private func withTempDirAsync(_ body: (URL) async throws -> Void) async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try await body(tmp)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    // MARK: - Initialize / open

    func testInitializeCreatesRepo() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            XCTAssertTrue(Repository.exists(at: dir))
            XCTAssertEqual(repo.workingDirectory.resolvingSymlinksInPath(), dir.resolvingSymlinksInPath())
        }
    }

    func testExistsReturnsFalse() {
        XCTAssertFalse(Repository.exists(at: URL(fileURLWithPath: "/tmp/no-such-repo-\(UUID())")))
    }

    func testOpenExisting() throws {
        try withTempDir { dir in
            try Repository.initialize(at: dir)
            let repo = try Repository.open(at: dir)
            XCTAssertEqual(repo.workingDirectory.resolvingSymlinksInPath(), dir.resolvingSymlinksInPath())
        }
    }

    // MARK: - Stage + Commit

    func testStageAndCommit() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("hello", to: "a.txt", in: dir)

            try repo.stage(paths: ["a.txt"])
            let commit = try repo.commit(message: "Initial commit", author: author)

            XCTAssertEqual(commit.subject, "Initial commit")
            XCTAssertEqual(commit.author.name, "Test")
            XCTAssertTrue(commit.parentIDs.isEmpty)
            XCTAssertEqual(commit.id.sha.count, 40)
        }
    }

    func testUnstageNewFile() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("hello", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])

            // Before unstage: file should be staged (.added)
            let before = try repo.status(includeUntracked: false)
            XCTAssertTrue(before.contains { $0.path == "a.txt" && $0.status == .added })

            try repo.unstage(paths: ["a.txt"])

            // After unstage with no HEAD: file is removed from index → shows as untracked
            let after = try repo.status(includeUntracked: true)
            XCTAssertTrue(after.contains { $0.path == "a.txt" && $0.status == .untracked })
        }
    }

    func testUnstageTrackedFile() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("v1", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            try repo.commit(message: "init", author: author)

            // Modify and stage
            try write("v2", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])

            // Before unstage: index differs from HEAD (staged diff is non-empty)
            let diffBefore = try repo.diff(from: "HEAD")
            XCTAssertTrue(diffBefore.contains { $0.newPath == "a.txt" })

            try repo.unstage(paths: ["a.txt"])

            // After unstage: index matches HEAD (no staged diff), change is in working tree only
            let diffAfter = try repo.diff()  // index → workdir
            XCTAssertTrue(diffAfter.contains { $0.newPath == "a.txt" })
        }
    }

    func testCommitChain() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("A", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            let first = try repo.commit(message: "First", author: author)

            try write("B", to: "b.txt", in: dir)
            try repo.stage(paths: ["b.txt"])
            let second = try repo.commit(message: "Second", author: author)

            XCTAssertEqual(second.parentIDs, [first.id])
        }
    }

    func testStageAll() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("v1", to: "file.txt", in: dir)
            try repo.stage(paths: ["file.txt"])
            try repo.commit(message: "init", author: author)

            try write("v2", to: "file.txt", in: dir)
            try write("new", to: "new.txt", in: dir)
            try repo.stageAll()
            let commit = try repo.commit(message: "stage all", author: author)
            XCTAssertEqual(commit.subject, "stage all")
        }
    }

    // MARK: - Status

    func testStatusModified() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("v1", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            try write("v2", to: "f.txt", in: dir)
            let entries = try repo.status()
            XCTAssertTrue(entries.contains { $0.path == "f.txt" && $0.status == .modified })
        }
    }

    func testStatusUntracked() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("x", to: "new.txt", in: dir)
            let entries = try repo.status()
            XCTAssertTrue(entries.contains { $0.path == "new.txt" && $0.status == .untracked })
        }
    }

    // MARK: - OID

    func testOIDRoundTrip() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("x", to: "x.txt", in: dir)
            try repo.stage(paths: ["x.txt"])
            let commit = try repo.commit(message: "test", author: author)

            XCTAssertEqual(commit.id.sha.count, 40)
            XCTAssertEqual(commit.id.abbreviated.count, 7)

            let reconstructed = OID(string: commit.id.sha)
            XCTAssertEqual(reconstructed, commit.id)
        }
    }

    // MARK: - Branches

    func testBranchCreate() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            let commit = try repo.commit(message: "init", author: author)

            let branch = try repo.branches.create(named: "feature", at: commit)
            XCTAssertEqual(branch.name, "feature")
            XCTAssertEqual(branch.tipID, commit.id)
        }
    }

    func testBranchList() throws {
        try withTempDir { dir in
            let repo = try Repository.initialize(at: dir)
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            try repo.commit(message: "init", author: author)

            let branches = try repo.branches.list()
            XCTAssertFalse(branches.isEmpty)
        }
    }
}
