import Foundation

/// A contiguous range of lines in a file that were last changed in the same commit.
public struct BlameHunk: Sendable, Identifiable {

    public var id: String { "\(commitID.sha)-\(startLine)" }

    /// The commit that last modified this range of lines.
    public let commitID:    OID
    /// The author of that commit.
    public let author:      Signature
    /// 1-based line number of the first line in the range.
    public let startLine:   Int
    /// Number of lines covered by this hunk.
    public let lineCount:   Int
    /// 1-based line range as a closed range.
    public var lineRange:   ClosedRange<Int> { startLine...(startLine + lineCount - 1) }
}
