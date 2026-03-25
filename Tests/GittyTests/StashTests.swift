import XCTest
@testable import Gitty

final class StashTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyStashTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    func testStashPushAndList() throws {
        try withRepo { dir, repo in
            try write("v1", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            try write("v2", to: "f.txt", in: dir)
            XCTAssertFalse(try repo.status().isEmpty)

            try repo.stash.push(message: "WIP", author: author)
            XCTAssertTrue(try repo.status().isEmpty)

            let entries = try repo.stash.list()
            XCTAssertEqual(entries.count, 1)
        }
    }

    func testStashPop() throws {
        try withRepo { dir, repo in
            try write("v1", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            try write("v2", to: "f.txt", in: dir)
            try repo.stash.push(message: "save", author: author)
            XCTAssertTrue(try repo.status().isEmpty)

            try repo.stash.pop()
            XCTAssertFalse(try repo.status().isEmpty)
        }
    }

    func testStashDrop() throws {
        try withRepo { dir, repo in
            try write("v1", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            try write("v2", to: "f.txt", in: dir)
            try repo.stash.push(author: author)

            var entries = try repo.stash.list()
            XCTAssertEqual(entries.count, 1)

            try repo.stash.drop()
            entries = try repo.stash.list()
            XCTAssertTrue(entries.isEmpty)
        }
    }

    func testStashEmptyThrows() throws {
        try withRepo { dir, repo in
            try write("v1", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            XCTAssertThrowsError(try repo.stash.push(author: author))
        }
    }
}
