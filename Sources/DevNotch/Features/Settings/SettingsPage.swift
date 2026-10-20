import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, alerts, accounts, shortcuts, updates, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .alerts: "Alerts"
        case .accounts: "Accounts"
        case .shortcuts: "Shortcuts"
        case .updates: "Updates"
        case .about: "About"
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
