import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AccountStore {
    private(set) var accounts: [Account] = []
    private(set) var tabs: [SavedFilter] = SavedFilter.defaults
    private(set) var runTabs: [RunTab] = RunTab.defaults
    private(set) var ghInstalled = true
    private(set) var ghUsers: [String] = []
    private(set) var importing: String?
    private(set) var importFailure: ImportFailure?

    @ObservationIgnored var onAccountAdded: ((Account) -> Void)?
    @ObservationIgnored var onAccountRemoved: ((Account) -> Void)?
    @ObservationIgnored var onTabsChanged: (() -> Void)?

    private let defaults: UserDefaults
    private let cli: any GitHubCLI
    private let tokens: TokenProvider

    init(defaults: UserDefaults, cli: any GitHubCLI, tokens: TokenProvider) {
        self.defaults = defaults
        self.cli = cli
        self.tokens = tokens
        if let data = defaults.data(for: .accounts) {
            do {
                accounts = try JSONDecoder().decode([Account].self, from: data)
            } catch {
                Logger.store.error("Saved accounts are unreadable: \(error.localizedDescription, privacy: .public)")
            }
        }
        loadTabs()
        reloadGHUsers()
    }

    var importableGHUsers: [String] {
        ghUsers.filter { user in !accounts.contains { $0.login.caseInsensitiveCompare(user) == .orderedSame } }
    }

    func remove(_ account: Account) {
        Task { await tokens.forget(account.login) }
        accounts.removeAll { $0.id == account.id }
        persist()
        let keptTabs = tabs.filter { $0.account != account.login }
        setTabs(keptTabs.isEmpty ? SavedFilter.defaults : keptTabs)
        let keptRunTabs = runTabs.filter { $0.account != account.login }
        setRunTabs(keptRunTabs.isEmpty ? RunTab.defaults : keptRunTabs)
        onAccountRemoved?(account)
    }

    func filters(for login: String) -> [SavedFilter] {
        tabs.filter { $0.applies(to: login) }
    }

    func setTabs(_ tabs: [SavedFilter]) {
        guard self.tabs != tabs else { return }
        self.tabs = tabs
        save(tabs, for: .tabs)
        onTabsChanged?()
    }

    func setRunTabs(_ tabs: [RunTab]) {
        guard runTabs != tabs else { return }
        runTabs = tabs
        save(tabs, for: .runTabs)
    }

    func reloadGHUsers() {
        let cli = cli
        Task { [weak self] in
            let (installed, users) = await Task.detached { (cli.isInstalled, cli.users()) }.value
            self?.ghInstalled = installed
            self?.ghUsers = users
        }
    }

    func importFromGH(_ user: String) async {
        importing = user
        importFailure = nil
        defer { importing = nil }
        do {
            let cli = cli
            let token = try await Task.detached { try cli.token(for: user) }.value
            let profile = try await GitHubClient(token: token).fetchUser()
            await tokens.remember(token, for: profile.login)
            upsert(Account(login: profile.login, avatarURL: profile.avatarURL))
        } catch {
            Logger.github.error("Adding @\(user, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            importFailure = ImportFailure(user: user, reason: error.localizedDescription)
        }
    }

    private func upsert(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        persist()
        onAccountAdded?(account)
    }

    private func loadTabs() {
        let decoder = JSONDecoder()
        let legacy = defaults.data(for: .accounts).flatMap { try? decoder.decode([LegacyAccount].self, from: $0) } ?? []
        if let data = defaults.data(for: .tabs), let saved = try? decoder.decode([SavedFilter].self, from: data) {
            tabs = saved
        } else if !legacy.isEmpty {
            tabs = SavedFilter.merging(legacy.map { ($0.login, $0.filters ?? SavedFilter.defaults) })
            save(tabs, for: .tabs)
        }
        if let data = defaults.data(for: .runTabs), let saved = try? decoder.decode([RunTab].self, from: data) {
            runTabs = saved
        } else if !legacy.isEmpty {
            runTabs = RunTab.merging(legacy.map { ($0.login, $0.runTabs ?? RunTab.defaults) })
            save(runTabs, for: .runTabs)
        }
    }

    private func save(_ value: some Encodable, for key: DefaultsKey) {
        do {
            try defaults.set(JSONEncoder().encode(value), for: key)
        } catch {
            Logger.store.error("Saving \(key.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        do {
            try defaults.set(JSONEncoder().encode(accounts), for: .accounts)
        } catch {
            Logger.store.error("Saving accounts failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct LegacyAccount: Decodable {
    let login: String
    let filters: [SavedFilter]?
    let runTabs: [RunTab]?

    enum CodingKeys: String, CodingKey {
        case login, filters, runTabs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        login = try container.decode(String.self, forKey: .login)
        filters = try? container.decodeIfPresent([SavedFilter].self, forKey: .filters)
        runTabs = try? container.decodeIfPresent([RunTab].self, forKey: .runTabs)
    }
}
