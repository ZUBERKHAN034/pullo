import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, appearance, alerts, accounts, tabs, shortcuts, updates, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .appearance: String(localized: "Appearance")
        case .alerts: String(localized: "Alerts")
        case .accounts: String(localized: "Accounts")
        case .tabs: String(localized: "Tabs")
        case .shortcuts: String(localized: "Shortcuts")
        case .updates: String(localized: "Updates")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .alerts: "bell.badge"
        case .accounts: "person.2"
        case .tabs: "rectangle.stack"
        case .shortcuts: "keyboard"
        case .updates: "arrow.down.circle"
        case .about: "info.circle"
        }
    }
}
