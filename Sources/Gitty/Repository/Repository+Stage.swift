import libgit2

extension Repository {

    // MARK: - Stage

    /// Stages specific paths (adds to index).
    ///
    /// Deleted files are automatically removed from the index rather than failing.
    public func stage(paths: [String]) throws {
        let idx = try openIndex()
        for path in paths {
            if git_index_add_bypath(idx.raw, path) != 0 {
                _ = git_index_remove_bypath(idx.raw, path)
            }
        }
        guard git_index_write(idx.raw) == 0 else {
            throw GittyError(message: "Could not write index after staging")
        }
    }

    /// Stages all tracked modifications, additions, and deletions (equivalent to `git add -u`).
    public func stageAll() throws {
        let idx = try openIndex()
        var opts = git_status_options()
        git_status_init_options(&opts, UInt32(GIT_STATUS_OPTIONS_VERSION))

        var statusList: OpaquePointer?
        guard git_status_list_new(&statusList, pointer, &opts) == 0, let statusList else {
            throw GittyError(message: "Could not read status for stageAll")
        }
        defer { git_status_list_free(statusList) }

        let count = git_status_list_entrycount(statusList)
        for i in 0..<count {
            guard let entry = git_status_byindex(statusList, i) else { continue }
            let flags = entry.pointee.status.rawValue
            let isDeleted = (flags & GIT_STATUS_WT_DELETED.rawValue) != 0
                         || (flags & GIT_STATUS_INDEX_DELETED.rawValue) != 0

            let pathPtr = entry.pointee.index_to_workdir?.pointee.old_file.path
                       ?? entry.pointee.head_to_index?.pointee.old_file.path
            guard let pathPtr else { continue }
            let path = String(cString: pathPtr)

            if isDeleted {
                _ = git_index_remove_bypath(idx.raw, path)
            } else {
                _ = git_index_add_bypath(idx.raw, path)
            }
        }
        guard git_index_write(idx.raw) == 0 else {
            throw GittyError(message: "Could not write index after stageAll")
        }
    }

    // MARK: - Unstage

    /// Removes the specified paths from the index, leaving the working tree untouched.
    ///
    /// When HEAD exists the index entry is reset to the HEAD tree state (tracked files
    /// revert to their last-committed version; new files staged for the first time are
    /// removed from the index entirely). When there is no HEAD (initial commit) all
    /// specified paths are simply removed from the index.
    public func unstage(paths: [String]) throws {
        let idx = try openIndex()

        var headCommitPtr: OpaquePointer?
        let hasHead = git_revparse_single(&headCommitPtr, pointer, "HEAD") == 0

        for path in paths {
            if hasHead, let headCommitPtr {
                var treePtr: OpaquePointer?
                if git_object_peel(&treePtr, headCommitPtr, GIT_OBJECT_TREE) == 0, let treePtr {
                    defer { git_tree_free(treePtr) }
                    var entry: OpaquePointer?
                    if git_tree_entry_bypath(&entry, treePtr, path) == 0, let entry {
                        defer { git_tree_entry_free(entry) }
                        var indexEntry = git_index_entry()
                        indexEntry.path = git_tree_entry_name(entry)
                        if let oid = git_tree_entry_id(entry) { indexEntry.id = oid.pointee }
                        indexEntry.mode = git_tree_entry_filemode_raw(entry).rawValue
                        _ = git_index_add(idx.raw, &indexEntry)
                    } else {
                        // New file not yet in HEAD — remove from index
                        _ = git_index_remove_bypath(idx.raw, path)
                    }
                }
            } else {
                // No HEAD (initial commit) — remove from index
                _ = git_index_remove_bypath(idx.raw, path)
            }
        }

        if let headCommitPtr { git_object_free(headCommitPtr) }

        guard git_index_write(idx.raw) == 0 else {
            throw GittyError(message: "Could not write index after unstage")
        }
    }

    // MARK: - Internal

    func openIndex() throws -> GitPointer {
        var idxPtr: OpaquePointer?
        guard git_repository_index(&idxPtr, pointer) == 0, let idxPtr else {
            throw GittyError(message: "Could not open repository index")
        }
        return .index(idxPtr)
    }
}
