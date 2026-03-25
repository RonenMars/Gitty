import libgit2

/// A per-file diff.
public struct FileDiff: Sendable, Identifiable {

    public var id: String { newPath ?? oldPath ?? "" }

    public let oldPath:       String?
    public let newPath:       String?
    public let status:        ChangeType
    public let hunks:         [Hunk]
    public let linesAdded:    Int
    public let linesDeleted:  Int

    public enum ChangeType: Sendable, Equatable, CustomStringConvertible {
        case added, deleted, modified, renamed, copied, unmodified

        public var description: String {
            switch self {
            case .added:      return "A"
            case .deleted:    return "D"
            case .modified:   return "M"
            case .renamed:    return "R"
            case .copied:     return "C"
            case .unmodified: return " "
            }
        }

        init(raw: git_delta_t) {
            switch raw {
            case GIT_DELTA_ADDED:    self = .added
            case GIT_DELTA_DELETED:  self = .deleted
            case GIT_DELTA_MODIFIED: self = .modified
            case GIT_DELTA_RENAMED:  self = .renamed
            case GIT_DELTA_COPIED:   self = .copied
            default:                 self = .unmodified
            }
        }
    }

    /// A contiguous block of changed lines.
    public struct Hunk: Sendable {
        /// The `@@ -a,b +c,d @@` header line.
        public let header: String
        public let lines:  [DiffLine]
    }

    /// A single line within a hunk.
    public struct DiffLine: Sendable {
        /// `+` added · `-` deleted · ` ` context.
        public let origin:         Character
        public let content:        String
        public let oldLineNumber:  Int?
        public let newLineNumber:  Int?
    }
}
