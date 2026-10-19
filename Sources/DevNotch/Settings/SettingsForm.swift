import AppKit
import SwiftUI

/// The pages of the settings window, listed in its sidebar.
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

/// System Settings–style window: a sidebar of pages and the selected page on the right.
struct SettingsForm: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var accounts: AccountStore
    let model: NotchViewModel
    /// Nil in demo mode, where nothing should reach the network.
    let updater: Updater?
    @ViewState private var page: SettingsPage? = .general

    var body: some View {
        NavigationSplitView {
            List(pages, selection: Binding(get: { page }, set: { page = $0 })) { page in
                Label(page.title, systemImage: page.symbol)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .formStyle(.grouped)
                .toggleStyle(.switch)
                .navigationTitle((page ?? .general).title)
        }
        .frame(width: 700, height: 500)
    }

    /// Updates only exist outside demo mode.
    private var pages: [SettingsPage] {
        SettingsPage.allCases.filter { $0 != .updates || updater != nil }
    }

    @ViewBuilder
    private var detail: some View {
        switch page ?? .general {
        case .general: GeneralPage(settings: settings)
        case .alerts: AlertsPage(settings: settings, accounts: accounts, model: model)
        case .accounts: AccountsPage(accounts: accounts)
        case .shortcuts: ShortcutsPage()
        case .updates: if let updater { UpdatesPage(updater: updater) }
        case .about: AboutPage()
        }
    }
}
