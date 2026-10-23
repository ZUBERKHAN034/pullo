import Foundation
@testable import Pullo
import Testing

struct PollGateTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func backsOffExponentiallyUpToFiveMinutes() {
        var gate = PollGate { 1 }
        let delays = (1...7).map { failures in gate.backoff(after: failures) }
        #expect(delays == [30, 60, 120, 240, 300, 300, 300])
        gate.failed("me", with: GitHubError.server(502), at: start)
        #expect(!gate.allows("me", at: start + 29))
        #expect(gate.allows("me", at: start + 30))
        gate.failed("me", with: GitHubError.server(502), at: start + 30)
        #expect(gate.next("me") == start + 90)
        gate.succeeded("me")
        #expect(gate.allows("me", at: start + 31))
    }

    @Test func jitterOnlyShortensTheWait() {
        let gate = PollGate { 0.75 }
        #expect(gate.backoff(after: 1) == 22.5)
        #expect(gate.backoff(after: 10) == 225)
    }

    @Test func waitsForTheRateLimitToReset() {
        var gate = PollGate { 1 }
        gate.failed("me", with: GitHubError.rateLimited(until: start + 1800), at: start)
        #expect(!gate.allows("me", at: start + 1799))
        gate.clearForManualRefresh()
        gate.clearBackoff()
        #expect(!gate.allows("me", at: start + 1799))
        #expect(gate.allows("me", at: start + 1800))
    }

    @Test func aRateLimitWithoutAResetWaitsFiveMinutes() {
        var gate = PollGate { 1 }
        gate.failed("me", with: GitHubError.rateLimited(until: nil), at: start)
        #expect(gate.next("me") == start + 300)
    }

    @Test func aSignInProblemWaitsForAManualRefresh() {
        var gate = PollGate { 1 }
        gate.failed("me", with: GitHubError.unauthorized, at: start)
        gate.failed("work", with: GitHubError.noToken, at: start)
        #expect(!gate.allows("me", at: start + 86400))
        gate.clearBackoff()
        #expect(!gate.allows("work", at: start + 86400))
        gate.clearForManualRefresh()
        #expect(gate.allows("me", at: start))
        #expect(gate.allows("work", at: start))
    }

    @Test func forgetsRemovedAccounts() {
        var gate = PollGate { 1 }
        gate.failed("gone", with: GitHubError.unauthorized, at: start)
        gate.prune(to: ["me"])
        #expect(gate.allows("gone", at: start))
    }
}

private final class FakeNetwork: NetworkPath {
    private var onChange: (@MainActor (Bool) -> Void)?

    func start(_ onChange: @escaping @MainActor (Bool) -> Void) { self.onChange = onChange }
    func cancel() {}

    @MainActor
    func set(reachable: Bool) { onChange?(reachable) }
}

private actor CountingSource: PRSource {
    private(set) var calls = 0
    private var failure: GitHubError?

    func fail(with error: GitHubError?) { failure = error }

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        calls += 1
        if let failure { throw failure }
        return Snapshot(mine: [], reviewRequests: [])
    }
}

extension NotchBehavior {
    @MainActor
    struct PollerTests {
        private let scratch = ScratchDefaults()

        private func store(_ source: CountingSource, clock: TestClock, now: @escaping () -> Date) -> PRStore {
            let defaults = scratch.defaults
            defaults.set(try? JSONEncoder().encode([Account(login: "me", avatarURL: nil)]), for: .accounts)
            return PRStore(
                accounts: AccountStore(defaults: defaults),
                tracker: ReadTracker(defaults: defaults),
                source: source,
                clock: clock,
                gate: PollGate { 1 },
                now: now
            )
        }

        @Test func pollsOnTheClock() async {
            let clock = TestClock()
            let source = CountingSource()
            let store = store(source, clock: clock) { .now }
            store.start()
            await clock.settle()
            #expect(await source.calls == 1)
            await clock.advance(by: .seconds(59))
            #expect(await source.calls == 1)
            await clock.advance(by: .seconds(1))
            #expect(await source.calls == 2)
            store.poller.stop()
        }

        @Test func stopsWhileOfflineAndRefreshesOnceWhenBack() async {
            let clock = TestClock()
            let source = CountingSource()
            let store = store(source, clock: clock) { .now }
            let network = FakeNetwork()
            let activity = ActivityMonitor(network: network)
            activity.watch([store.poller])
            network.start { activity.set(.offline, !$0) }
            store.start()
            await clock.settle()
            #expect(await source.calls == 1)

            network.set(reachable: false)
            await clock.advance(by: .seconds(600))
            #expect(await source.calls == 1)

            network.set(reachable: true)
            await clock.settle()
            #expect(await source.calls == 2)
            network.set(reachable: true)
            await clock.settle()
            #expect(await source.calls == 2)
            store.poller.stop()
        }

        @Test func sleepAndLockBothHaveToEndBeforePollingAgain() async {
            let clock = TestClock()
            let source = CountingSource()
            let store = store(source, clock: clock) { .now }
            let activity = ActivityMonitor(network: FakeNetwork())
            activity.watch([store.poller])
            store.start()
            await clock.settle()
            activity.set(.systemAsleep, true)
            activity.set(.locked, true)
            activity.set(.systemAsleep, false)
            await clock.advance(by: .seconds(120))
            #expect(await source.calls == 1)
            activity.set(.locked, false)
            await clock.settle()
            #expect(await source.calls == 2)
            store.poller.stop()
        }

        @Test func waitsForTheRateLimitToResetBeforeAskingAgain() async {
            let clock = TestClock()
            let source = CountingSource()
            var now = Date(timeIntervalSince1970: 1_000_000)
            let store = store(source, clock: clock) { now }
            await source.fail(with: .rateLimited(until: now + 600))
            store.start()
            await clock.settle()
            #expect(await source.calls == 1)
            #expect(store.errors["me"]?.kind == .rateLimited)
            await source.fail(with: nil)
            for _ in 0..<9 {
                now += 60
                await clock.advance(by: .seconds(60))
            }
            #expect(await source.calls == 1)
            now += 60
            await clock.advance(by: .seconds(60))
            #expect(await source.calls == 2)
            #expect(store.errors["me"] == nil)
            store.poller.stop()
        }

        @Test func aRejectedTokenStopsPollingUntilAskedTo() async {
            let clock = TestClock()
            let source = CountingSource()
            let store = store(source, clock: clock) { .now }
            await source.fail(with: .unauthorized)
            store.start()
            await clock.settle()
            await clock.advance(by: .seconds(600))
            #expect(await source.calls == 1)
            await source.fail(with: nil)
            await store.refresh()
            #expect(await source.calls == 2)
            #expect(store.errors["me"] == nil)
            store.poller.stop()
        }

        @Test func backsOffWhileGitHubKeepsFailing() async {
            let clock = TestClock()
            let source = CountingSource()
            var now = Date(timeIntervalSince1970: 1_000_000)
            let store = store(source, clock: clock) { now }
            await source.fail(with: .server(502))
            store.start()
            await clock.settle()
            for _ in 0..<10 {
                now += 60
                await clock.advance(by: .seconds(60))
            }
            #expect(await source.calls == 5)
            store.poller.stop()
        }
    }
}

struct TokenProviderTests {
    private actor CountingCLI: GitHubCLI {
        private(set) var calls = 0
        var token: String?

        func set(_ token: String?) { self.token = token }
        func isInstalled() async -> Bool { true }
        func users() async -> [String] { ["me"] }

        func token(for user: String) async throws -> String {
            calls += 1
            try await Task.sleep(for: .milliseconds(20))
            guard let token else { throw GitHubError.noToken }
            return token
        }
    }

    @Test func aFailureIsRememberedForAWhile() async throws {
        let cli = CountingCLI()
        let clock = Locked(Date(timeIntervalSince1970: 1_000_000))
        let tokens = TokenProvider(cli: cli) { clock.value }
        await #expect(throws: GitHubError.noToken) { try await tokens.token(for: "me") }
        await cli.set("secret")
        await #expect(throws: GitHubError.noToken) { try await tokens.token(for: "me") }
        #expect(await cli.calls == 1)
        clock.value += TokenProvider.failureCooldown
        #expect(try await tokens.token(for: "me") == "secret")
        #expect(await cli.calls == 2)
    }

    @Test func checkingAgainForgetsFailures() async throws {
        let cli = CountingCLI()
        let tokens = TokenProvider(cli: cli)
        _ = try? await tokens.token(for: "me")
        await cli.set("secret")
        await tokens.clearFailures()
        #expect(try await tokens.token(for: "me") == "secret")
    }

    @Test func asksGhOnceForCallersAtTheSameTime() async throws {
        let cli = CountingCLI()
        await cli.set("secret")
        let tokens = TokenProvider(cli: cli)
        async let first = tokens.token(for: "me")
        async let second = tokens.token(for: "me")
        #expect(try await [first, second] == ["secret", "secret"])
        #expect(await cli.calls == 1)
    }
}

final class Locked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

struct GHLocationTests {
    private let home = "/Users/me"

    @Test func usesWhatTheLoginShellFound() {
        let output = "Welcome!\n\n__PULLO_GH__\n/Users/me/.nix-profile/bin/gh\n\n/Users/me/.xdg\n"
        let location = GHLocation.resolve(environment: [:], home: home, shellOutput: output) { $0 == "/Users/me/.nix-profile/bin/gh" }
        #expect(location.executable == "/Users/me/.nix-profile/bin/gh")
        #expect(location.configDirectory == "/Users/me/.xdg/gh")
    }

    @Test func fallsBackToKnownFolders() {
        let location = GHLocation.resolve(environment: [:], home: home, shellOutput: nil) { $0 == "/opt/local/bin/gh" }
        #expect(location.executable == "/opt/local/bin/gh")
        #expect(location.configDirectory == "/Users/me/.config/gh")
    }

    @Test func ignoresAnAnswerThatIsNotAPath() {
        let output = "\n__PULLO_GH__\ngh: aliased to hub\n\n\n"
        let location = GHLocation.resolve(environment: [:], home: home, shellOutput: output) { _ in false }
        #expect(location.executable == nil)
    }

    @Test func theConfigFolderFollowsGhsRules() {
        let output = "\n__PULLO_GH__\n/usr/local/bin/gh\n/Users/me/gh-shell\n/Users/me/.xdg-shell\n"
        let exists: (String) -> Bool = { _ in true }
        #expect(GHLocation.resolve(environment: ["GH_CONFIG_DIR": "/cfg"], home: home, shellOutput: output, isExecutable: exists)
            .configDirectory == "/cfg")
        #expect(GHLocation.resolve(environment: [:], home: home, shellOutput: output, isExecutable: exists)
            .configDirectory == "/Users/me/gh-shell")
        #expect(GHLocation.resolve(environment: ["XDG_CONFIG_HOME": "/xdg"], home: home, shellOutput: nil, isExecutable: exists)
            .configDirectory == "/xdg/gh")
    }

    @Test func ghNeverPromptsAndFindsItsConfig() {
        let location = GHLocation(executable: "/opt/local/bin/gh", configDirectory: "/Users/me/.xdg/gh")
        #expect(location.environment["GH_PROMPT_DISABLED"] == "1")
        #expect(location.environment["GH_CONFIG_DIR"] == "/Users/me/.xdg/gh")
        #expect(location.environment["PATH"]?.hasPrefix("/opt/local/bin:") == true)
    }
}

struct ProcessRunnerTests {
    @Test func readsTheOutput() async throws {
        let output = try await ProcessRunner.run("/bin/echo", ["hello"], timeout: .seconds(5))
        #expect(output.status == 0)
        #expect(String(decoding: output.stdout, as: UTF8.self) == "hello\n")
    }

    @Test func givesUpOnAProcessThatHangs() async {
        let started = Date()
        await #expect(throws: ProcessRunner.TimedOut.self) {
            try await ProcessRunner.run("/bin/sleep", ["30"], timeout: .milliseconds(200))
        }
        #expect(Date().timeIntervalSince(started) < 5)
    }
}
