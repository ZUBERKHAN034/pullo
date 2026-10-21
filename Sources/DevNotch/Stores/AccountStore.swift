import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AccountStore {
    private(set) var accounts: [Account] = []
    private(set) var ghInstalled = true
    private(set) var ghUsers: [String] = []
    private(set) var importing: String?
    private(set) var importFailure: ImportFailure?

    @ObservationIgnored var onAccountAdded: ((Account) -> Void)?
    @ObservationIgnored var onAccountRemoved: ((Account) -> Void)?
    @ObservationIgnored var onFiltersChanged: ((Account) -> Void)?

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
        reloadGHUsers()
    }

    var importableGHUsers: [String] {
        ghUsers.filter { user in !accounts.contains { $0.login.caseInsensitiveCompare(user) == .orderedSame } }
    }

    func remove(_ account: Account) {
        Task { await tokens.forget(account.login) }
        accounts.removeAll { $0.id == account.id }
        persist()
        onAccountRemoved?(account)
    }

    func filters(for login: String) -> [SavedFilter] {
        accounts.first { $0.login == login }?.filters ?? []
    }

    func setFilters(_ filters: [SavedFilter], for login: String) {
        guard let index = accounts.firstIndex(where: { $0.login == login }), accounts[index].filters != filters else { return }
        accounts[index].filters = filters
        persist()
        onFiltersChanged?(accounts[index])
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
        var account = account
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            account.filters = accounts[index].filters
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        persist()
        onAccountAdded?(account)
    }

    private func persist() {
        do {
            try defaults.set(JSONEncoder().encode(accounts), for: .accounts)
        } catch {
            Logger.store.error("Saving accounts failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
