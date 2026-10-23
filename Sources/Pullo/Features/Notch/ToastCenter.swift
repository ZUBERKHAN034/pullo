import Observation
import SwiftUI

@MainActor
@Observable
final class ToastCenter {
    static let displayTime: Duration = .seconds(1.8)

    private(set) var message: String?

    private let clock: any Clock<Duration>
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init(clock: any Clock<Duration> = ContinuousClock()) {
        self.clock = clock
    }

    func show(_ message: String) {
        hideTask?.cancel()
        withAnimation(Motion.navigate) { self.message = message }
        let clock = clock
        hideTask = Task { [weak self] in
            try? await clock.sleep(for: Self.displayTime)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { self?.message = nil }
        }
    }
}
