import XCTest
@testable import Gitty

final class TagTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyTagTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    private func seed(_ repo: Repository, dir: URL) throws -> Commit {
        try write("seed", to: "seed.txt", in: dir)
        try repo.stage(paths: ["seed.txt"])
        return try repo.commit(message: "seed", author: author)
    }

    func testCreateLightweightTag() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            let tag = try repo.tags.create(named: "v1.0", at: commit)
            XCTAssertEqual(tag.name, "v1.0")
            XCTAssertEqual(tag.targetID, commit.id)
            XCTAssertNil(tag.message)
        }
    }

    func testCreateAnnotatedTag() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            let tag = try repo.tags.create(
                named: "v2.0",
                at: commit,
                message: "Release v2.0",
                tagger: author
            )
            XCTAssertEqual(tag.name, "v2.0")
            XCTAssertEqual(tag.message, "Release v2.0")
            XCTAssertEqual(tag.tagger?.name, "Test")
        }
    }

    func testListTags() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            try repo.tags.create(named: "alpha", at: commit)
            try repo.tags.create(named: "beta", at: commit)
            let names = try repo.tags.list().map(\.name)
            XCTAssertTrue(names.contains("alpha"))
            XCTAssertTrue(names.contains("beta"))
        }
    }

    func testDeleteTag() throws {
        try withRepo { dir, repo in
            let commit = try seed(repo, dir: dir)
            try repo.tags.create(named: "to-delete", at: commit)
            try repo.tags.delete(named: "to-delete")
            let names = try repo.tags.list().map(\.name)
            XCTAssertFalse(names.contains("to-delete"))
        }
    }
}
