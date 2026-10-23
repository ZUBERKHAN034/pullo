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
        inFlight[login] = task
        defer { if inFlight[login] == task { inFlight[login] = nil } }
        do {
            let token = try await task.value
            tokens[login] = token
            failures[login] = nil
            return token
        } catch {
            failures[login] = Failure(error: error, until: now().addingTimeInterval(Self.failureCooldown))
            throw error
        }
    }

    func remember(_ token: String, for login: String) {
        tokens[login] = token
        failures[login] = nil
    }

    func forget(_ login: String) {
        tokens[login] = nil
    }

    func clearFailures() {
        failures = [:]
    }
}
