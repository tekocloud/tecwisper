import Foundation

/// Prevents a superseded request from publishing a result or completion time.
struct ConnectionCheckRun {
    private(set) var id = UUID()
    private(set) var isRunning = false
    private(set) var completedAt: Date?
    mutating func invalidate() { id = UUID(); isRunning = false; completedAt = nil }
    mutating func begin() -> UUID { id = UUID(); isRunning = true; completedAt = nil; return id }
    func accepts(_ token: UUID) -> Bool { token == id }
    mutating func complete(_ token: UUID, at date: Date = Date()) {
        guard accepts(token) else { return }
        isRunning = false; completedAt = date
    }
}
