import libgit2

/// A file with a non-clean status in the working tree or index.
public struct StatusEntry: Sendable, Identifiable {

    public var id: String { path }
    public let path:   String
    public let status: Status

    public enum Status: Sendable, Equatable, CustomStringConvertible {
        case modified
        case added
        case deleted
        case untracked
        case renamed(from: String)
        case typeChanged

        public var description: String {
            switch self {
            case .modified:   return "M"
            case .added:      return "A"
            case .deleted:    return "D"
            case .untracked:  return "?"
            case .renamed:    return "R"
            case .typeChanged: return "T"
            }
        }

        static func from(flags: git_status_t, oldPath: String?) -> Status {
            let raw = flags.rawValue
            if raw & GIT_STATUS_WT_NEW.rawValue    != 0 { return .untracked }
            if raw & GIT_STATUS_INDEX_NEW.rawValue  != 0 { return .added }
            if raw & (GIT_STATUS_INDEX_DELETED.rawValue | GIT_STATUS_WT_DELETED.rawValue) != 0 {
                return .deleted
            }
            if raw & (GIT_STATUS_INDEX_RENAMED.rawValue | GIT_STATUS_WT_RENAMED.rawValue) != 0 {
                return .renamed(from: oldPath ?? "")
            }
            if raw & (GIT_STATUS_INDEX_TYPECHANGE.rawValue | GIT_STATUS_WT_TYPECHANGE.rawValue) != 0 {
                return .typeChanged
            }
            return .modified
        }
    }
}
