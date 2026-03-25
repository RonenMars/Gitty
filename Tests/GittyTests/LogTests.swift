import XCTest
@testable import Gitty

final class LogTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) async throws -> Void) async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyLogTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try await body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    func testLogIteratesAllCommits() async throws {
        try await withRepo { [author] dir, repo in
            for i in 1...5 {
                try write("\(i)", to: "f\(i).txt", in: dir)
                try repo.stage(paths: ["f\(i).txt"])
                try repo.commit(message: "commit \(i)", author: author)
            }
            var messages: [String] = []
            for try await commit in repo.log() {
                messages.append(commit.subject)
            }
            XCTAssertEqual(messages.count, 5)
            // All 5 commit messages are present (exact order may vary for same-second timestamps)
            for i in 1...5 {
                XCTAssertTrue(messages.contains("commit \(i)"), "Missing: commit \(i)")
            }
        }
    }

    func testLogLimit() async throws {
        try await withRepo { [author] dir, repo in
            for i in 1...5 {
                try write("\(i)", to: "g\(i).txt", in: dir)
                try repo.stage(paths: ["g\(i).txt"])
                try repo.commit(message: "msg \(i)", author: author)
            }
            var count = 0
            for try await _ in repo.log(limit: 3) {
                count += 1
            }
            XCTAssertEqual(count, 3)
        }
    }

    func testLogFromRef() async throws {
        try await withRepo { [author] dir, repo in
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            let first = try repo.commit(message: "first", author: author)

            try write("b", to: "b.txt", in: dir)
            try repo.stage(paths: ["b.txt"])
            try repo.commit(message: "second", author: author)

            var messages: [String] = []
            for try await commit in repo.log(from: first.id.sha) {
                messages.append(commit.subject)
            }
            // Starting from first commit — only that commit visible
            XCTAssertEqual(messages, ["first"])
        }
    }
}
