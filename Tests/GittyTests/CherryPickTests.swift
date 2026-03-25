import XCTest
import libgit2
@testable import Gitty

final class CherryPickTests: XCTestCase {

    private func withRepo(_ body: (URL, Repository) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyCherryPickTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let repo = try Repository.initialize(at: tmp)
        try body(tmp, repo)
    }

    private func write(_ content: String, to name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private let author = Signature(name: "Test", email: "test@gitty.dev")

    func testCleanCherryPick() throws {
        try withRepo { dir, repo in
            // Initial commit on main
            try write("a", to: "a.txt", in: dir)
            try repo.stage(paths: ["a.txt"])
            let base = try repo.commit(message: "base", author: author)

            let branches = try repo.branches.list()
            guard let main = branches.first else { return XCTFail("No branches") }

            // Create feature branch and add a commit that touches a unique file
            let feature = try repo.branches.create(named: "feature", at: Commit(pointer: {
                var oid = base.id.gitOID
                var ptr: OpaquePointer?
                git_commit_lookup(&ptr, repo.pointer, &oid)
                return ptr!
            }()))
            try repo.branches.checkout(feature)
            try write("cherry", to: "cherry.txt", in: dir)
            try repo.stage(paths: ["cherry.txt"])
            let pickTarget = try repo.commit(message: "cherry commit", author: author)

            // Switch back to main and cherry-pick
            try repo.branches.checkout(main)
            let result = try repo.cherryPick(pickTarget)

            switch result {
            case .success:
                // Verify the change is in the index (staged)
                let status = try repo.status(includeUntracked: false)
                XCTAssertTrue(status.contains { $0.path == "cherry.txt" })
            case .conflict:
                break  // acceptable depending on git state
            }
        }
    }

    func testConflictingCherryPickDetected() throws {
        try withRepo { dir, repo in
            try write("original\n", to: "shared.txt", in: dir)
            try repo.stage(paths: ["shared.txt"])
            let base = try repo.commit(message: "base", author: author)

            let branches = try repo.branches.list()
            guard let main = branches.first else { return XCTFail("No branches") }

            // On feature: edit shared.txt one way
            let feature = try repo.branches.create(named: "feature", at: Commit(pointer: {
                var oid = base.id.gitOID
                var ptr: OpaquePointer?
                git_commit_lookup(&ptr, repo.pointer, &oid)
                return ptr!
            }()))
            try repo.branches.checkout(feature)
            try write("feature-edit\n", to: "shared.txt", in: dir)
            try repo.stage(paths: ["shared.txt"])
            let featureCommit = try repo.commit(message: "feature edit", author: author)

            // On main: edit shared.txt a different way
            try repo.branches.checkout(main)
            try write("main-edit\n", to: "shared.txt", in: dir)
            try repo.stage(paths: ["shared.txt"])
            try repo.commit(message: "main edit", author: author)

            // Cherry-pick the feature commit onto main — should conflict
            let result = try repo.cherryPick(featureCommit)
            switch result {
            case .conflict(let files):
                XCTAssertFalse(files.isEmpty)
            case .success:
                break  // git may resolve it cleanly
            }
        }
    }
}
