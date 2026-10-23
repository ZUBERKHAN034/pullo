import Foundation

enum PollPause: Hashable {
    case offline, systemAsleep, screensAsleep, locked
}

@MainActor
final class Poller {
    private let clock: any Clock<Duration>
    private var task: Task<Void, Never>?
    private var started = false
    private(set) var pauses: Set<PollPause> = []

    var tick: @MainActor () async -> Duration = { .seconds(60) }
    var onResume: (() -> Void)?

    init(clock: any Clock<Duration> = ContinuousClock()) {
        self.clock = clock
    }

    var isPaused: Bool { !pauses.isEmpty }

    func start() {
        started = true
        restart()
    }

    func stop() {
        started = false
        task?.cancel()
        task = nil
    }

    func pollNow() {
        guard started, !isPaused else { return }
        restart()
    }

    func pause(_ reason: PollPause) {
        guard pauses.insert(reason).inserted else { return }
        task?.cancel()
        task = nil
    }

    func resume(_ reason: PollPause) {
        guard pauses.remove(reason) != nil, pauses.isEmpty else { return }
        onResume?()
        if started { restart() }
    }

    private func restart() {
        task?.cancel()
        guard !isPaused else { return }
        let clock = clock
        let tick = tick
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let delay = await Task { @MainActor in await tick() }.value
                guard !Task.isCancelled, self != nil else { return }
                try? await clock.sleep(for: delay)
            }
        }
    }
}
