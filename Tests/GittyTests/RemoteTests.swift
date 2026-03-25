import XCTest
@testable import Gitty

final class RemoteTests: XCTestCase {

    private func withRepos(_ body: (URL, Repository, URL) throws -> Void) throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("GittyRemoteTests-\(UUID().uuidString)")
        let repoDir = base.appendingPathComponent("repo")
        let bareDir = base.appendingPathComponent("bare.git")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bareDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let repo = try Repository.initialize(at: repoDir)
        _ = try Repository.initialize(at: bareDir, bare: true)
        try body(repoDir, repo, bareDir)
    }

    func testAddRemote() throws {
        try withRepos { _, repo, bareDir in
            let remote = try repo.remotes.add(name: "origin", url: bareDir.path)
            XCTAssertEqual(remote.name, "origin")
            XCTAssertEqual(remote.url, bareDir.path)
        }
    }

    func testListRemotes() throws {
        try withRepos { _, repo, bareDir in
            try repo.remotes.add(name: "origin", url: bareDir.path)
            let remotes = try repo.remotes.list()
            XCTAssertTrue(remotes.contains { $0.name == "origin" })
        }
    }

    func testRemoveRemote() throws {
        try withRepos { _, repo, bareDir in
            try repo.remotes.add(name: "origin", url: bareDir.path)
            try repo.remotes.remove(named: "origin")
            let remotes = try repo.remotes.list()
            XCTAssertFalse(remotes.contains { $0.name == "origin" })
        }
    }

    func testRenameRemote() throws {
        try withRepos { _, repo, bareDir in
            try repo.remotes.add(name: "origin", url: bareDir.path)
            try repo.remotes.rename(from: "origin", to: "upstream")
            let remotes = try repo.remotes.list()
            XCTAssertTrue(remotes.contains { $0.name == "upstream" })
            XCTAssertFalse(remotes.contains { $0.name == "origin" })
        }
    }
}
