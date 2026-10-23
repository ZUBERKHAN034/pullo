import Foundation

actor TokenProvider {
    static let failureCooldown: TimeInterval = 5 * 60

    private struct Failure {
        let error: Error
        let until: Date
    }

    private let cli: any GitHubCLI
    private let now: @Sendable () -> Date
    private var tokens: [String: String] = [:]
    private var failures: [String: Failure] = [:]
    private var inFlight: [String: Task<String, Error>] = [:]
    private var generations: [String: Int] = [:]

    init(cli: any GitHubCLI, now: @escaping @Sendable () -> Date = Date.init) {
        self.cli = cli
        self.now = now
    }

    func token(for login: String) async throws -> String {
        if let cached = tokens[login] { return cached }
        if let failure = failures[login], now() < failure.until { throw failure.error }
        if let running = inFlight[login] { return try await running.value }
        let cli = cli
        let task = Task { try await cli.token(for: login) }
        let generation = generations[login, default: 0]
        inFlight[login] = task
        defer { if inFlight[login] == task { inFlight[login] = nil } }
        do {
            let token = try await task.value
            if generations[login, default: 0] == generation {
                tokens[login] = token
                failures[login] = nil
            }
            return token
        } catch {
            if generations[login, default: 0] == generation {
                failures[login] = Failure(error: error, until: now().addingTimeInterval(Self.failureCooldown))
            }
            throw error
        }
    }

    nonisolated func withToken<T: Sendable>(
        for login: String,
        _ request: @Sendable (String) async throws -> T
    ) async throws -> T {
        let token = try await token(for: login)
        do {
            return try await request(token)
        } catch GitHubError.unauthorized {
            await drop(token, for: login)
            throw GitHubError.unauthorized
        }
    }

    private func drop(_ token: String, for login: String) {
        if tokens[login] == token { tokens[login] = nil }
    }

    func remember(_ token: String, for login: String) {
        tokens[login] = token
        failures[login] = nil
    }

    func forget(_ login: String) {
        tokens[login] = nil
        failures[login] = nil
        inFlight[login] = nil
        generations[login, default: 0] += 1
    }

    func clearFailures() {
        failures = [:]
    }
}
