import libgit2

/// A configured remote in a git repository.
public struct Remote: Sendable, Identifiable, Hashable {

    public var id: String { name }

    /// The remote's short name, e.g. `origin`.
    public let name: String
    /// The fetch/push URL.
    public let url:  String

    // MARK: - Internal

    init(name: String, url: String) {
        self.name = name
        self.url  = url
    }

    init?(pointer: OpaquePointer) {
        guard let nameCStr = git_remote_name(pointer),
              let urlCStr  = git_remote_url(pointer)  else { return nil }
        self.name = String(cString: nameCStr)
        self.url  = String(cString: urlCStr)
    }
}
