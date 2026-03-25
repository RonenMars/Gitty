import libgit2

/// A git tag (lightweight or annotated).
public struct Tag: Sendable, Identifiable, Hashable {

    public var id: String { fullName }

    /// Short name, e.g. `v1.0.0`.
    public let name:     String
    /// Full ref name, e.g. `refs/tags/v1.0.0`.
    public let fullName: String
    /// The OID the tag points to (the tagged commit for lightweight tags,
    /// or the tag object itself for annotated tags).
    public let targetID: OID
    /// Message from an annotated tag, or `nil` for lightweight tags.
    public let message:  String?
    /// Tagger identity for annotated tags.
    public let tagger:   Signature?

    // MARK: - Internal

    init(refPointer ref: OpaquePointer, repoPointer repo: OpaquePointer) {
        guard let nameCStr = git_reference_name(ref) else {
            self.name = ""; self.fullName = ""; self.targetID = OID(string: String(repeating: "0", count: 40))!
            self.message = nil; self.tagger = nil; return
        }
        self.fullName = String(cString: nameCStr)
        self.name = fullName.hasPrefix("refs/tags/")
            ? String(fullName.dropFirst("refs/tags/".count))
            : fullName

        // Peel to the underlying object OID
        var obj: OpaquePointer?
        git_reference_peel(&obj, ref, GIT_OBJECT_ANY)
        let rawOID = obj.flatMap { git_object_id($0).map { OID(raw: $0.pointee) } }
        if let obj { git_object_free(obj) }
        self.targetID = rawOID ?? OID(string: String(repeating: "0", count: 40))!

        // Try to read annotation
        var tagOID = git_oid()
        if git_reference_name_to_id(&tagOID, repo, nameCStr) == 0 {
            var tagPtr: OpaquePointer?
            if git_tag_lookup(&tagPtr, repo, &tagOID) == 0, let tagPtr {
                self.message = git_tag_message(tagPtr).map { String(cString: $0) }
                self.tagger  = git_tag_tagger(tagPtr).map { Signature(raw: $0) }
                git_tag_free(tagPtr)
                return
            }
        }
        self.message = nil
        self.tagger  = nil
    }
}
