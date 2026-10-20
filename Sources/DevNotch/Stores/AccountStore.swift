import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var ghInstalled = true
    @Published private(set) var ghUsers: [String] = []
    @Published private(set) var importing: String?
    @Published private(set) var importError: String?

    var onAccountAdded: ((Account) -> Void)?
    var onAccountRemoved: ((Account) -> Void)?

    private let defaults: UserDefaults
    private var tokens: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(for: .accounts),
           let saved = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = saved
        }
        reloadGHUsers()
    }

    var importableGHUsers: [String] {
        ghUsers.filter { user in !accounts.contains { $0.login.caseInsensitiveCompare(user) == .orderedSame } }
    }

    func token(for account: Account) async throws -> String {
        if let cached = tokens[account.login] { return cached }
        let login = account.login
        let token = try await Task.detached { try GHCLI.token(for: login) }.value
        tokens[login] = token
        return token
    }

    func invalidateToken(for login: String) {
        tokens[login] = nil
    }

    func remove(_ account: Account) {
        tokens[account.login] = nil
        accounts.removeAll { $0.id == account.id }
        persist()
        onAccountRemoved?(account)
    }

    func reloadGHUsers() {
        Task { [weak self] in
            let (installed, users) = await Task.detached { (GHCLI.isInstalled, GHCLI.users()) }.value
            self?.ghInstalled = installed
            self?.ghUsers = users
        }
    }

    func importFromGH(_ user: String) async {
        importing = user
        importError = nil
        defer { importing = nil }
        do {
            let token = try await Task.detached { try GHCLI.token(for: user) }.value
            let profile = try await GitHubClient(token: token).fetchUser()
            tokens[profile.login] = token
            upsert(Account(login: profile.login, avatarURL: profile.avatarURL))
        } catch {
            importError = "@\(user): \(error.localizedDescription)"
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

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, for: .accounts)
        }
    }
}
