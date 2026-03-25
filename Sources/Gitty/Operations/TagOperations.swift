import libgit2

/// Namespace for tag operations: `repo.tags.list()`, `repo.tags.create(...)`, etc.
public struct TagOperations: Sendable {
    let repository: Repository

    // MARK: - List

    /// Returns all tags in the repository.
    public func list() throws -> [Tag] {
        var names = git_strarray()
        let code  = git_tag_list(&names, repository.pointer)
        guard code == 0 else { throw GittyError(code: code) }
        defer { git_strarray_free(&names) }

        var result: [Tag] = []
        for i in 0..<names.count {
            guard let nameCStr = names.strings?[i] else { continue }
            let fullName = "refs/tags/" + String(cString: nameCStr)

            var refPtr: OpaquePointer?
            guard git_reference_lookup(&refPtr, repository.pointer, fullName) == 0, let refPtr else { continue }
            let ref = GitPointer.reference(refPtr)
            result.append(Tag(refPointer: ref.raw, repoPointer: repository.pointer))
        }
        return result
    }

    // MARK: - Create lightweight

    /// Creates a lightweight tag pointing at `commit`.
    @discardableResult
    public func create(named name: String, at commit: Commit, force: Bool = false) throws -> Tag {
        var oid    = commit.id.gitOID
        var tagOID = git_oid()
        var obj: OpaquePointer?
        guard git_object_lookup(&obj, repository.pointer, &oid, GIT_OBJECT_COMMIT) == 0, let obj else {
            throw GittyError(message: "Could not look up commit \(commit.id.abbreviated)")
        }
        let objBox = GitPointer.object(obj)
        let code   = git_tag_create_lightweight(&tagOID, repository.pointer, name, objBox.raw, force ? 1 : 0)
        guard code == 0 else { throw GittyError(code: code) }

        let fullName = "refs/tags/\(name)"
        var refPtr: OpaquePointer?
        guard git_reference_lookup(&refPtr, repository.pointer, fullName) == 0, let refPtr else {
            throw GittyError(message: "Could not read tag '\(name)' after creation")
        }
        let ref = GitPointer.reference(refPtr)
        return Tag(refPointer: ref.raw, repoPointer: repository.pointer)
    }

    // MARK: - Create annotated

    /// Creates an annotated tag with a message.
    @discardableResult
    public func create(
        named name: String,
        at commit: Commit,
        message: String,
        tagger: Signature,
        force: Bool = false
    ) throws -> Tag {
        var oid    = commit.id.gitOID
        var tagOID = git_oid()
        var obj: OpaquePointer?
        guard git_object_lookup(&obj, repository.pointer, &oid, GIT_OBJECT_COMMIT) == 0, let obj else {
            throw GittyError(message: "Could not look up commit \(commit.id.abbreviated)")
        }
        let objBox = GitPointer.object(obj)
        let sigPtr = try tagger.makePointer()
        let sig    = GitPointer.signature(sigPtr)

        let code = git_tag_create(&tagOID, repository.pointer, name, objBox.raw, sigPtr, message, force ? 1 : 0)
        _ = sig
        guard code == 0 else { throw GittyError(code: code) }

        let fullName = "refs/tags/\(name)"
        var refPtr: OpaquePointer?
        guard git_reference_lookup(&refPtr, repository.pointer, fullName) == 0, let refPtr else {
            throw GittyError(message: "Could not read tag '\(name)' after creation")
        }
        let ref = GitPointer.reference(refPtr)
        return Tag(refPointer: ref.raw, repoPointer: repository.pointer)
    }

    // MARK: - Delete

    /// Deletes the tag named `name`.
    public func delete(named name: String) throws {
        let code = git_tag_delete(repository.pointer, name)
        guard code == 0 else { throw GittyError(code: code) }
    }
}
