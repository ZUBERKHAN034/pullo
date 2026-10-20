import Foundation

enum DefaultsKey: String {
    case accounts
    case mutedCategories, mutedAccounts, haptics, sound, panelStyle
    case readBaselines, readKnownAccounts
    case betaUpdates
}

extension UserDefaults {
    func set(_ value: Any?, for key: DefaultsKey) { set(value, forKey: key.rawValue) }
    func object(for key: DefaultsKey) -> Any? { object(forKey: key.rawValue) }
    func data(for key: DefaultsKey) -> Data? { data(forKey: key.rawValue) }
    func stringArray(for key: DefaultsKey) -> [String]? { stringArray(forKey: key.rawValue) }
}
