import libgit2

extension Repository {

    /// Returns all files with a non-clean status in the working tree and index.
    public func status(includeUntracked: Bool = true) throws -> [StatusEntry] {
        var opts = git_status_options()
        git_status_init_options(&opts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR

        var flags: UInt32 = UInt32(GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue)
        if includeUntracked {
            flags |= UInt32(GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue)
            flags |= UInt32(GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue)
        }
        opts.flags = flags

        var list: OpaquePointer?
        guard git_status_list_new(&list, pointer, &opts) == 0, let list else {
            throw GittyError(message: "Could not read git status")
        }
        defer { git_status_list_free(list) }

        let count = git_status_list_entrycount(list)
        var entries: [StatusEntry] = []

        for i in 0..<count {
            guard let entry = git_status_byindex(list, i) else { continue }
            let flags = entry.pointee.status
            guard flags != GIT_STATUS_CURRENT else { continue }

            let oldPath: String?
            let newPath: String?

            if let diff = entry.pointee.index_to_workdir {
                oldPath = diff.pointee.old_file.path.map { String(cString: $0) }
                newPath = diff.pointee.new_file.path.map { String(cString: $0) }
            } else if let diff = entry.pointee.head_to_index {
                oldPath = diff.pointee.old_file.path.map { String(cString: $0) }
                newPath = diff.pointee.new_file.path.map { String(cString: $0) }
            } else {
                continue
            }

            let path   = newPath ?? oldPath ?? ""
            let status = StatusEntry.Status.from(flags: flags, oldPath: oldPath)
            entries.append(StatusEntry(path: path, status: status))
        }

        return entries
    }
}
