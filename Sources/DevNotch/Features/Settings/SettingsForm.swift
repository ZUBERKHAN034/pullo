import AppKit
import SwiftUI

struct SettingsForm: View {
    @Environment(AccountStore.self) private var accounts
    let updater: Updater?
    @Bindable var navigation: SettingsNavigation

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
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .alerts: AlertsPage()
        case .accounts: AccountsPage()
        case .filters: FiltersPage()
        case .shortcuts: ShortcutsPage()
        case .updates: if let updater { UpdatesPage(updater: updater) }
        case .about: AboutPage()
        }
    }
}
