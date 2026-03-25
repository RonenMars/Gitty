/// A single entry in the stash stack.
public struct StashEntry: Sendable, Identifiable {
    /// Position in the stash stack (`0` = most recent).
    public let id:       Int
    public let message:  String
    public let commitID: OID
}
