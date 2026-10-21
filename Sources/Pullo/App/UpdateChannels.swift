import Foundation
import Sparkle

final class UpdateChannels: NSObject, SPUUpdaterDelegate {
    static let beta = "beta"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var receivesBetas: Bool {
        get { defaults.object(for: .betaUpdates) as? Bool ?? false }
        set { defaults.set(newValue, for: .betaUpdates) }
    }

    var allowed: Set<String> { receivesBetas ? [Self.beta] : [] }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        allowed
    }
}
