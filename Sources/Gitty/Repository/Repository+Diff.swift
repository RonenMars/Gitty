import libgit2

extension Repository {

    // MARK: - Public API

    /// Diff between the index and the working tree (unstaged changes).
    public func diff() throws -> [FileDiff] {
        var diffPtr: OpaquePointer?
        let code = git_diff_index_to_workdir(&diffPtr, pointer, nil, nil)
        guard code == 0, let diffPtr else { throw GittyError(code: code) }
        return try buildFileDiffs(GitPointer.diff(diffPtr))
    }

    /// Diff between the given ref (default `HEAD`) and the working tree, including staged changes.
    public func diff(from refName: String = "HEAD") throws -> [FileDiff] {
        let tree = try treePointer(refName: refName, in: pointer)
        var diffPtr: OpaquePointer?
        let code = git_diff_tree_to_workdir_with_index(&diffPtr, pointer, tree.raw, nil)
        guard code == 0, let diffPtr else { throw GittyError(code: code) }
        return try buildFileDiffs(GitPointer.diff(diffPtr))
    }

    /// Diff between two commits.
    public func diff(from: Commit, to: Commit) throws -> [FileDiff] {
        let fromTree = try treePointer(forCommitOID: from.id.sha, in: pointer)
        let toTree   = try treePointer(forCommitOID: to.id.sha,   in: pointer)
        var diffPtr: OpaquePointer?
        let code = git_diff_tree_to_tree(&diffPtr, pointer, fromTree.raw, toTree.raw, nil)
        guard code == 0, let diffPtr else { throw GittyError(code: code) }
        return try buildFileDiffs(GitPointer.diff(diffPtr))
    }

    // MARK: - Private

    private func buildFileDiffs(_ diffBox: GitPointer) throws -> [FileDiff] {
        let count = git_diff_num_deltas(diffBox.raw)
        var results: [FileDiff] = []
        results.reserveCapacity(Int(count))

        for i in 0..<count {
            guard let delta = git_diff_get_delta(diffBox.raw, i) else { continue }
            let oldPath    = delta.pointee.old_file.path.map { String(cString: $0) }
            let newPath    = delta.pointee.new_file.path.map { String(cString: $0) }
            let changeType = FileDiff.ChangeType(raw: delta.pointee.status)

            var patchPtr: OpaquePointer?
            guard git_patch_from_diff(&patchPtr, diffBox.raw, i) == 0, let patchPtr else {
                results.append(FileDiff(oldPath: oldPath, newPath: newPath,
                                        status: changeType, hunks: [],
                                        linesAdded: 0, linesDeleted: 0))
                continue
            }
            let patch = GitPointer.patch(patchPtr)

            var context = 0, added = 0, deleted = 0
            git_patch_line_stats(&context, &added, &deleted, patch.raw)

            let numHunks = git_patch_num_hunks(patch.raw)
            var hunks: [FileDiff.Hunk] = []

            for h in 0..<numHunks {
                var hunkPtr: UnsafePointer<git_diff_hunk>?
                var numLines = 0
                guard git_patch_get_hunk(&hunkPtr, &numLines, patch.raw, h) == 0,
                      let hunkPtr else { continue }

                let headerBytes = withUnsafeBytes(of: hunkPtr.pointee.header) { Array($0) }
                let header = String(bytes: headerBytes.prefix(Int(hunkPtr.pointee.header_len)),
                                    encoding: .utf8) ?? ""

                var lines: [FileDiff.DiffLine] = []
                for l in 0..<numLines {
                    var linePtr: UnsafePointer<git_diff_line>?
                    guard git_patch_get_line_in_hunk(&linePtr, patch.raw, h, l) == 0,
                          let linePtr else { continue }

                    let origin = Character(Unicode.Scalar(UInt8(linePtr.pointee.origin)))
                    let content: String
                    if let contentPtr = linePtr.pointee.content {
                        let len = Int(linePtr.pointee.content_len)
                        content = contentPtr.withMemoryRebound(to: UInt8.self, capacity: len) {
                            String(bytes: UnsafeBufferPointer(start: $0, count: len), encoding: .utf8)
                        } ?? ""
                    } else {
                        content = ""
                    }
                    let oldLine = linePtr.pointee.old_lineno > 0 ? Int(linePtr.pointee.old_lineno) : nil
                    let newLine = linePtr.pointee.new_lineno > 0 ? Int(linePtr.pointee.new_lineno) : nil
                    lines.append(FileDiff.DiffLine(origin: origin, content: content,
                                                   oldLineNumber: oldLine, newLineNumber: newLine))
                }
                hunks.append(FileDiff.Hunk(header: header, lines: lines))
            }

            results.append(FileDiff(oldPath: oldPath, newPath: newPath,
                                    status: changeType, hunks: hunks,
                                    linesAdded: added, linesDeleted: deleted))
        }
        return results
    }
}
