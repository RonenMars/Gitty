import Foundation
import libgit2

/// An error surfaced from a Gitty operation.
public struct GittyError: Error, LocalizedError, CustomStringConvertible, Sendable {

    public let code: Int32
    public let message: String

    public var errorDescription: String? { message }
    public var description: String { "GittyError(\(code)): \(message)" }

    init(code: Int32) {
        self.code    = code
        self.message = git_error_last().map { String(cString: $0.pointee.message) }
            ?? "libgit2 error (code \(code))"
    }

    init(message: String, code: Int32 = -1) {
        self.code    = code
        self.message = message
    }
}
