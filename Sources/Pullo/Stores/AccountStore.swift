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
    private let session: URLSession
    private let clock: any Clock<Duration>
    @ObservationIgnored private var knownGHUsers: Set<String>?
    @ObservationIgnored private var watchTicks = 0
    @ObservationIgnored private var loginWatch: Task<Void, Never>?

    init(
        defaults: UserDefaults,
        cli: any GitHubCLI,
        tokens: TokenProvider,
        session: URLSession = .shared,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.defaults = defaults
        self.cli = cli
        self.tokens = tokens
        self.session = session
        self.clock = clock
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

    func reloadGHUsers(recheck: Bool = false) {
        Task { [weak self] in await self?.loadGHUsers(recheck: recheck) }
    }

    @discardableResult
    func loadGHUsers(recheck: Bool = false) async -> [String] {
        if recheck {
            await cli.recheck()
            await tokens.clearFailures()
        }
        let installed = await cli.isInstalled()
        let users = await cli.users()
        ghInstalled = installed
        ghUsers = users
        return users
    }

    func watchForGHLogins(every interval: Duration = .seconds(3)) {
        guard loginWatch == nil else { return }
        let clock = clock
        loginWatch = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForNewLogins()
                try? await clock.sleep(for: interval)
                if self == nil { return }
            }
        }
    }

    private func checkForNewLogins() async {
        guard accounts.isEmpty else {
            knownGHUsers = nil
            return
        }
        guard importing == nil else { return }
        watchTicks += 1
        let users = await loadGHUsers(recheck: !ghInstalled && watchTicks.isMultiple(of: 10))
        if let known = knownGHUsers {
            let added = users.filter { !known.contains($0.lowercased()) && importableGHUsers.contains($0) }
            if !added.isEmpty { await tokens.clearFailures() }
            for user in added {
                await importFromGH(user)
            }
        }
        knownGHUsers = Set(users.map { $0.lowercased() })
    }

    func importFromGH(_ user: String) async {
        importing = user
        importFailure = nil
        defer { importing = nil }
        do {
            let token = try await cli.token(for: user)
            let profile = try await GitHubClient(token: token, session: session).fetchUser()
            await tokens.remember(token, for: profile.login)
            upsert(Account(login: profile.login, avatarURL: profile.avatarURL))
        } catch {
            Logger.github.error(
                "Adding @\(user, privacy: .private(mask: .hash)) failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            importFailure = ImportFailure(user: user, error: error)
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
        if defaults.object(for: .tabs) != nil {
            let saved: [SavedFilter] = loadList(.tabs, keepingUnreadableIn: .unreadableTabs)
            if !saved.isEmpty { tabs = saved }
        } else if !legacy.isEmpty {
            tabs = SavedFilter.merging(legacy.map { ($0.login, $0.filters ?? SavedFilter.defaults) })
            save(tabs, for: .tabs)
        }
        if defaults.object(for: .runTabs) != nil {
            let saved: [RunTab] = loadList(.runTabs, keepingUnreadableIn: .unreadableRunTabs)
            if !saved.isEmpty { runTabs = saved }
        } else if !legacy.isEmpty {
            runTabs = RunTab.merging(legacy.map { ($0.login, $0.runTabs ?? RunTab.defaults) })
            save(runTabs, for: .runTabs)
        }
    }

    private func loadList<Element: Decodable>(_ key: DefaultsKey, keepingUnreadableIn backup: DefaultsKey) -> [Element] {
        let stored = defaults.object(for: key)
        let decoded = (stored as? Data).flatMap { try? JSONDecoder().decode([Lenient<Element>].self, from: $0) }
        let kept = decoded?.compactMap(\.value) ?? []
        if decoded == nil || kept.count != decoded?.count {
            Logger.store.error("Some saved \(key.rawValue, privacy: .public) are unreadable; keeping a copy")
            defaults.set(stored, for: backup)
        }
        return kept
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
