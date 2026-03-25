import XCTest
@testable import Gitty

final class DiffTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyDiffTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    func testDiffFromHEAD() throws {
        try withRepo { dir, repo in
            try write("line1\n", to: "code.swift", in: dir)
            try repo.stage(paths: ["code.swift"])
            try repo.commit(message: "add", author: author)

            try write("line1\nline2\n", to: "code.swift", in: dir)

            let diffs = try repo.diff(from: "HEAD")
            XCTAssertEqual(diffs.count, 1)
            XCTAssertEqual(diffs.first?.newPath, "code.swift")
            XCTAssertEqual(diffs.first?.status, .modified)
            XCTAssertGreaterThan(diffs.first?.linesAdded ?? 0, 0)
        }
    }

    func testDiffBetweenCommits() throws {
        try withRepo { dir, repo in
            try write("v1\n", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            let c1 = try repo.commit(message: "v1", author: author)

            try write("v2\n", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            let c2 = try repo.commit(message: "v2", author: author)

            let diffs = try repo.diff(from: c1, to: c2)
            XCTAssertEqual(diffs.count, 1)
            XCTAssertEqual(diffs.first?.status, .modified)
        }
    }

    func testDiffHunksNotEmpty() throws {
        try withRepo { dir, repo in
            try write("line1\nline2\nline3\n", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            try write("line1\nLINE2\nline3\n", to: "f.txt", in: dir)

            let diffs = try repo.diff(from: "HEAD")
            XCTAssertFalse(diffs.first?.hunks.isEmpty ?? true)
            XCTAssertFalse(diffs.first?.hunks.first?.lines.isEmpty ?? true)
        }
    }
}
