import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, alerts, accounts, shortcuts, updates, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .alerts: String(localized: "Alerts")
        case .accounts: String(localized: "Accounts")
        case .shortcuts: String(localized: "Shortcuts")
        case .updates: String(localized: "Updates")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .alerts: "bell.badge"
        case .accounts: "person.2"
        case .shortcuts: "keyboard"
        case .updates: "arrow.down.circle"
        case .about: "info.circle"
        }
    }
}
