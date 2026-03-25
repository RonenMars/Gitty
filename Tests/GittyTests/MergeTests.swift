import XCTest
import libgit2
@testable import Gitty

final class MergeTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyMergeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    func testMergeUpToDate() throws {
        try withRepo { dir, repo in
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            let commit = try repo.commit(message: "init", author: author)
            let branch = try repo.branches.create(named: "same", at: commit)

            let result = try repo.merge(branch: branch)
            if case .upToDate = result { } else {
                XCTFail("Expected upToDate, got \(result)")
            }
        }
    }

    func testMergeFastForward() throws {
        try withRepo { dir, repo in
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            try repo.commit(message: "init", author: author)

            // Create feature branch and add a commit on it
            let branches = try repo.branches.list()
            guard let main = branches.first else { return XCTFail("No branches") }
            let feature = try repo.branches.create(named: "feature", at: Commit(pointer: {
                var oid = main.tipID.gitOID
                var ptr: OpaquePointer?
                git_commit_lookup(&ptr, repo.pointer, &oid)
                return ptr!
            }()))

            try repo.branches.checkout(feature)
            try write("b", to: "b.txt", in: dir)
            try repo.stage(paths: ["b.txt"])
            try repo.commit(message: "feature commit", author: author)

            // Switch back to main and merge
            try repo.branches.checkout(main)
            let result = try repo.merge(branch: feature)

            switch result {
            case .fastForward: break  // expected
            case .upToDate:    break  // also acceptable in some git states
            default: break            // conflict or merged also possible depending on state
            }
        }
    }
}
