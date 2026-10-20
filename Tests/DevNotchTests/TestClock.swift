import Foundation

final class TestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let id: UUID
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resumeNow: Bool = lock.withLock {
                    if Task.isCancelled || deadline <= current { return true }
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return false
                }
                if resumeNow { continuation.resume() }
            }
            try Task.checkCancellation()
        } onCancel: {
            let sleeper = lock.withLock {
                sleepers.firstIndex { $0.id == id }.map { sleepers.remove(at: $0) }
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) async {
        let target = now.advanced(by: duration)
        while true {
            await settle()
            let next: Sleeper? = lock.withLock {
                guard let index = sleepers.indices.min(by: { sleepers[$0].deadline < sleepers[$1].deadline }),
                      sleepers[index].deadline <= target
                else { return nil }
                let sleeper = sleepers.remove(at: index)
                current = max(current, sleeper.deadline)
                return sleeper
            }
            guard let next else { break }
            next.continuation.resume()
        }
        lock.withLock { current = target }
        await settle()
    }

    func settle() async {
        for _ in 0..<10 {
            await Task.detached(priority: .low) { await Task.yield() }.value
            await Task.yield()
        }
    }
}
