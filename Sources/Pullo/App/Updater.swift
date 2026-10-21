import Combine
import Sparkle

@MainActor
final class Updater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let channels: UpdateChannels
    private let controller: SPUStandardUpdaterController

    init(channels: UpdateChannels = UpdateChannels()) {
        self.channels = channels
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: channels, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var receivesBetas: Bool {
        get { channels.receivesBetas }
        set {
            objectWillChange.send()
            channels.receivesBetas = newValue
            controller.updater.resetUpdateCycleAfterShortDelay()
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
