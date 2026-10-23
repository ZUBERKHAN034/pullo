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
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .alerts: "bell.badge.fill"
        case .accounts: "person.2.fill"
        case .tabs: "rectangle.stack.fill"
        case .shortcuts: "keyboard.fill"
        case .updates: "arrow.down.circle.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general, .shortcuts, .about: .gray
        case .appearance: .blue
        case .alerts: .red
        case .accounts: .indigo
        case .tabs: .orange
        case .updates: .green
        }
    }
}
