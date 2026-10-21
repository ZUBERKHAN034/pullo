import Foundation

struct AlertQueue {
    private var pending: [NotchAlert] = []

    var isEmpty: Bool { pending.isEmpty }

    mutating func append(_ alerts: [NotchAlert]) {
        pending += alerts
    }

    mutating func removeAll() {
        pending.removeAll()
    }

    mutating func next() -> NotchAlert? {
        guard !pending.isEmpty else { return nil }
        let alert = pending.count > 1 ? NotchAlert.summary(of: pending) : pending[0]
        pending.removeAll()
        return alert
    }

    static func displayTime(for alert: NotchAlert) -> Duration {
        alert.stack.isEmpty ? .seconds(4.5) : .seconds(6)
    }
}
