import AppKit
import SwiftUI

struct SettingsForm: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var accounts: AccountStore
    let model: NotchViewModel
    let updater: Updater?
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(pages, selection: $navigation.page) { page in
                Label(page.title, systemImage: page.symbol)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .formStyle(.grouped)
                .toggleStyle(.switch)
                .navigationTitle((navigation.page ?? .general).title)
        }
        .frame(width: 700, height: 500)
    }

    private var pages: [SettingsPage] {
        SettingsPage.allCases.filter { $0 != .updates || updater != nil }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.page ?? .general {
        case .general: GeneralPage(settings: settings)
        case .alerts: AlertsPage(settings: settings, accounts: accounts, model: model)
        case .accounts: AccountsPage(accounts: accounts)
        case .shortcuts: ShortcutsPage()
        case .updates: if let updater { UpdatesPage(updater: updater) }
        case .about: AboutPage()
        }
    }
}
