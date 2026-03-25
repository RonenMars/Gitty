import libgit2

/// Network transfer progress reported during clone / fetch operations.
public struct TransferProgress: Sendable {
    public let totalObjects:    Int
    public let receivedObjects: Int
    public let localObjects:    Int
    public let totalDeltas:     Int
    public let indexedDeltas:   Int
    public let receivedBytes:   Int

    /// A value between `0.0` and `1.0` suitable for driving a progress indicator.
    public var fractionCompleted: Double {
        guard totalObjects > 0 else { return 0 }
        return Double(receivedObjects) / Double(totalObjects)
    }

    init(raw: git_indexer_progress) {
        totalObjects    = Int(raw.total_objects)
        receivedObjects = Int(raw.received_objects)
        localObjects    = Int(raw.local_objects)
        totalDeltas     = Int(raw.total_deltas)
        indexedDeltas   = Int(raw.indexed_deltas)
        receivedBytes   = Int(raw.received_bytes)
    }
}
