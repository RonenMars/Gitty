import libgit2

extension Repository {

    /// Returns blame information for every line in a file.
    ///
    /// ```swift
    /// let hunks = try repo.blame(file: "Sources/App/Login.swift")
    /// for hunk in hunks {
    ///     print("\(hunk.lineRange)  \(hunk.author)  \(hunk.commitID.abbreviated)")
    /// }
    /// ```
    ///
    /// - Parameter path: Path relative to the repository root.
    public func blame(file path: String) throws -> [BlameHunk] {
        var opts = git_blame_options()
        git_blame_init_options(&opts, UInt32(GIT_BLAME_OPTIONS_VERSION))

        var blamePtr: OpaquePointer?
        let code = git_blame_file(&blamePtr, pointer, path, &opts)
        guard code == 0, let blamePtr else { throw GittyError(code: code) }
        let blame = GitPointer.blame(blamePtr)

        let count = git_blame_get_hunk_count(blame.raw)
        var hunks: [BlameHunk] = []
        hunks.reserveCapacity(Int(count))

        for i in 0..<count {
            guard let hunk = git_blame_get_hunk_byindex(blame.raw, i) else { continue }

            let oid    = OID(raw: hunk.pointee.final_commit_id)
            let author = hunk.pointee.final_signature.map { Signature(raw: $0) }
                      ?? Signature(name: "Unknown", email: "")
            let start  = Int(hunk.pointee.final_start_line_number)
            let count  = Int(hunk.pointee.lines_in_hunk)

            hunks.append(BlameHunk(commitID: oid, author: author,
                                   startLine: start, lineCount: count))
        }
        return hunks
    }
}
