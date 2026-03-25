import XCTest
@testable import Gitty

final class BlameTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyBlameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Blame Author", email: "blame@gitty.dev")

    func testBlameReturnsHunks() throws {
        try withRepo { dir, repo in
            let content = (1...5).map { "line \($0)" }.joined(separator: "\n") + "\n"
            try write(content, to: "blamed.txt", in: dir)
            try repo.stage(paths: ["blamed.txt"])
            try repo.commit(message: "add file", author: author)

            let hunks = try repo.blame(file: "blamed.txt")
            XCTAssertFalse(hunks.isEmpty)
            XCTAssertEqual(hunks.first?.author.name, "Blame Author")
        }
    }

    func testBlameCoverAllLines() throws {
        try withRepo { dir, repo in
            try write("A\nB\nC\n", to: "f.txt", in: dir)
            try repo.stage(paths: ["f.txt"])
            try repo.commit(message: "init", author: author)

            let hunks = try repo.blame(file: "f.txt")
            let totalLines = hunks.reduce(0) { $0 + $1.lineCount }
            XCTAssertEqual(totalLines, 3)
        }
    }

    func testBlameCommitID() throws {
        try withRepo { dir, repo in
            try write("x\n", to: "x.txt", in: dir)
            try repo.stage(paths: ["x.txt"])
            let commit = try repo.commit(message: "add x", author: author)

            let hunks = try repo.blame(file: "x.txt")
            XCTAssertEqual(hunks.first?.commitID, commit.id)
        }
    }
}
