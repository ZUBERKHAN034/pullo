import AppKit
import Observation
import OSLog
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    var mutedCategories: Set<AlertCategory> { didSet { save() } }
    var mutedAccounts: Set<String> { didSet { save() } }
    var haptics: Bool { didSet { save() } }
    var sound: String? { didSet { save() } }
    var categorySounds: [AlertCategory: String] { didSet { save() } }
    var panelStyle: PanelStyle { didSet { save() } }
    var showsLiveCI: Bool { didSet { save() } }
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
        let storedCategorySounds = defaults.object(for: .categorySounds) as? [String: String] ?? [:]
        categorySounds = Dictionary(uniqueKeysWithValues: storedCategorySounds.compactMap { key, value in
            AlertCategory(rawValue: key).map { ($0, value) }
        })
        panelStyle = (defaults.object(for: .panelStyle) as? String).flatMap(PanelStyle.init(rawValue:)) ?? .solid
        showsLiveCI = defaults.object(for: .liveCI) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func allows(_ event: PREvent) -> Bool {
        !mutedCategories.contains(AlertCategory(event)) && !mutedAccounts.contains(event.pr.account)
    }

    func sound(for category: AlertCategory?) -> String? {
        guard let category, let chosen = categorySounds[category] else { return sound }
        return chosen.isEmpty ? nil : chosen
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
            Logger.settings.error("Changing open at login failed: \(error.localizedDescription, privacy: .public)")
            launchAtLoginFailure = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save() {
        defaults.set(mutedCategories.map(\.rawValue), for: .mutedCategories)
        defaults.set(Array(mutedAccounts), for: .mutedAccounts)
        defaults.set(haptics, for: .haptics)
        defaults.set(sound ?? "", for: .sound)
        defaults.set(Dictionary(uniqueKeysWithValues: categorySounds.map { ($0.key.rawValue, $0.value) }), for: .categorySounds)
        defaults.set(panelStyle.rawValue, for: .panelStyle)
        defaults.set(showsLiveCI, for: .liveCI)
    }
}
