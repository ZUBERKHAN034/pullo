import Foundation

@MainActor
final class RefreshQueue {
    private(set) var isRunning = false
    private var queued = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func run(_ work: @MainActor () async -> Void) async {
        guard !isRunning else {
            queued = true
            await withCheckedContinuation { waiting.append($0) }
            return
        }
        isRunning = true
        repeat {
            queued = false
            let served = waiting
            waiting = []
            await work()
            for waiter in served { waiter.resume() }
        } while queued
        isRunning = false
    }
}
