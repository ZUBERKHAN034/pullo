import AppKit
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    @Published var mutedCategories: Set<AlertCategory> { didSet { save() } }
    @Published var mutedAccounts: Set<String> { didSet { save() } }
    @Published var haptics: Bool { didSet { save() } }
    /// The name of a system sound, or nil for silent alerts.
    @Published var sound: String? { didSet { save() } }
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(for: .mutedCategories) ?? []
        mutedCategories = Set(stored.compactMap(AlertCategory.init(rawValue:)))
        mutedAccounts = Set(defaults.stringArray(for: .mutedAccounts) ?? [])
        haptics = defaults.object(for: .haptics) as? Bool ?? true
        let storedSound = defaults.object(for: .sound) as? String ?? "Glass"
        sound = storedSound.isEmpty ? nil : storedSound
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func allows(_ event: PREvent) -> Bool {
        !mutedCategories.contains(AlertCategory(event)) && !mutedAccounts.contains(event.pr.account)
    }

    func toggle(_ category: AlertCategory) {
        if mutedCategories.contains(category) { mutedCategories.remove(category) } else { mutedCategories.insert(category) }
    }

    func toggleAccount(_ login: String) {
        if mutedAccounts.contains(login) { mutedAccounts.remove(login) } else { mutedAccounts.insert(login) }
    }

    static let systemSounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        return files.map { ($0 as NSString).deletingPathExtension }.sorted()
    }()

    func playSound() {
        guard let sound, let player = NSSound(named: sound) else { return }
        player.stop()
        player.play()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't turn it on: \(error.localizedDescription). Install the app in /Applications."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save() {
        defaults.set(mutedCategories.map(\.rawValue), for: .mutedCategories)
        defaults.set(Array(mutedAccounts), for: .mutedAccounts)
        defaults.set(haptics, for: .haptics)
        defaults.set(sound ?? "", for: .sound)
    }
}
