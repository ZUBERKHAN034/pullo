import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    var mutedCategories: Set<AlertCategory> { didSet { save() } }
    var mutedAccounts: Set<String> { didSet { save() } }
    var haptics: Bool { didSet { save() } }
    var sound: String? { didSet { save() } }
    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginFailure: String?

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

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginFailure = nil
        } catch {
            launchAtLoginFailure = error.localizedDescription
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
