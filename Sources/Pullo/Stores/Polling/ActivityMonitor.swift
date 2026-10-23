import AppKit
import OSLog

@MainActor
final class ActivityMonitor {
    private let network: any NetworkPath
    private var pollers: [Poller] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(network: any NetworkPath = LiveNetworkPath()) {
        self.network = network
    }

    func watch(_ pollers: [Poller]) {
        self.pollers = pollers
    }

    func start() {
        network.start { [weak self] reachable in self?.set(.offline, !reachable) }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, .systemAsleep, true)
        observe(workspace, NSWorkspace.didWakeNotification, .systemAsleep, false)
        observe(workspace, NSWorkspace.screensDidSleepNotification, .screensAsleep, true)
        observe(workspace, NSWorkspace.screensDidWakeNotification, .screensAsleep, false)
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .locked, true)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .locked, false)
    }

    func set(_ pause: PollPause, _ active: Bool) {
        Logger.store.info("Polling pause \(String(describing: pause), privacy: .public): \(active, privacy: .public)")
        for poller in pollers {
            if active { poller.pause(pause) } else { poller.resume(pause) }
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ pause: PollPause, _ active: Bool) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.set(pause, active) }
        }
        observers.append((center, token))
    }
}
