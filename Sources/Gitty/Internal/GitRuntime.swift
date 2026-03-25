import Foundation
import libgit2

/// Manages one-time global init/shutdown of the libgit2 runtime.
enum GitRuntime {
    private static let lock     = NSLock()
    private static var refCount = 0

    static func initialize() {
        lock.lock()
        defer { lock.unlock() }
        if refCount == 0 { git_libgit2_init() }
        refCount += 1
    }

    @discardableResult
    static func shutdown() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard refCount > 0 else { return false }
        refCount -= 1
        if refCount == 0 { git_libgit2_shutdown() }
        return true
    }
}
