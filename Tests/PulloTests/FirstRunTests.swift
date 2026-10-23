import AppKit
@testable import Pullo
import Testing

extension NotchBehavior {
    @MainActor
    struct FirstRunTests {
        @Test func openingTheAppAgainShowsThePanelUntilDismissed() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1")])
            h.notch.reopen()
            #expect(h.notch.state == .open)
            #expect(h.list.selectedPRID == "PR_1")
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
            #expect(h.notch.perform(.close))
            #expect(h.notch.state == .closed)
        }

        @Test func openingTheAppAgainWhileOpenKeepsItOpen() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.reopen()
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
        }

        @Test func setupStaysOpenWhileTheUserGoesToTerminal() async {
            let h = await NotchHarness(accounts: [])
            h.notch.open()
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            h.notch.mouseDown(at: h.outside)
            #expect(h.notch.state == .open)
            #expect(h.notch.perform(.close))
            #expect(h.notch.state == .closed)
        }

        @Test func arrowKeysAfterHoverKeepThePanelOpen() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1"), .make(id: "PR_2")])
            h.notch.mouseMoved(to: h.inside(.closed))
            await h.clock.advance(by: .milliseconds(80))
            #expect(h.notch.state == .open)
            #expect(h.notch.perform(.moveDown))
            #expect(h.list.selectedPRID == "PR_1")
            #expect(h.list.keyboardMode)
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
        }

        @Test func commandCommaOpensSettings() async {
            let h = await NotchHarness()
            var opened = false
            h.notch.onOpenSettings = { _ in opened = true }
            h.notch.open()
            #expect(h.notch.perform(.settings))
            #expect(opened)
        }

        @Test func ciProgressShowsOnThePillWithoutANotch() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1", ci: .pending, checks: CheckProgress(done: 1, total: 3))])
            h.notch.geometry = NotchGeometry(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                notchSize: CGSize(width: NotchGeometry.pillWidth, height: 24),
                hasNotch: false
            )
            #expect(h.notch.liveCI?.id == "PR_1")
            #expect(h.notch.layout.size(for: .closed).width > NotchGeometry.pillWidth)
        }
    }
}

@MainActor
struct GHLoginWatchTests {
    private let scratch = ScratchDefaults()
    private let clock = TestClock()

    private func store(_ cli: LoginCLI, profile: String = "ana") -> AccountStore {
        let token = UUID().uuidString
        cli.token = token
        let session = StubURLProtocol.session(
            token: token,
            responses: [.init(status: 200, body: #"{ "login": "\#(profile)", "avatar_url": null }"#)]
        )
        return AccountStore(defaults: scratch.defaults, cli: cli, tokens: TokenProvider(cli: cli), session: session, clock: clock)
    }

    @Test func addsAnAccountAsSoonAsItLogsIntoGH() async {
        let cli = LoginCLI()
        let accounts = store(cli)
        accounts.watchForGHLogins()
        await waitForTheNextCheck()
        #expect(accounts.accounts.isEmpty)

        cli.logins = ["ana"]
        await clock.advance(by: .seconds(3))
        await waitUntil { !accounts.accounts.isEmpty }
        #expect(accounts.accounts.map(\.login) == ["ana"])
    }

    @Test func leavesAccountsThatWereAlreadyLoggedInForTheUserToPick() async {
        let cli = LoginCLI()
        cli.logins = ["ana"]
        let accounts = store(cli)
        accounts.watchForGHLogins()
        for _ in 0..<3 {
            await waitForTheNextCheck()
            await clock.advance(by: .seconds(3))
        }
        await waitForTheNextCheck()
        #expect(accounts.accounts.isEmpty)
        #expect(accounts.importableGHUsers == ["ana"])
    }

    @Test func showsWhyAnAutomaticAddFailed() async {
        let cli = LoginCLI()
        let accounts = store(cli)
        cli.token = nil
        accounts.watchForGHLogins()
        await waitForTheNextCheck()
        cli.logins = ["ana"]
        await clock.advance(by: .seconds(3))
        await waitUntil { accounts.importFailure != nil }
        #expect(accounts.importFailure == ImportFailure(user: "ana", reason: .notLoggedIn))
        #expect(accounts.importFailure?.recovery == .copy("gh auth login"))
    }

    private func waitForTheNextCheck() async {
        await waitUntil { clock.hasSleepers }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

struct ImportFailureTests {
    @Test func explainsCommonGHProblemsWithAWayOut() {
        #expect(ImportFailure(user: "me", error: GitHubError.noToken).reason == .notLoggedIn)
        #expect(ImportFailure(user: "me", error: GitHubError.unauthorized).recovery == .copy("gh auth login"))
        #expect(ImportFailure(user: "me", error: GitHubError.ghTimedOut).recovery == .retry)
        #expect(ImportFailure(user: "me", error: GitHubError.offline).reason == .offline)
        #expect(ImportFailure(user: "me", error: GitHubError.server(502)).reason == .unreachable)
        #expect(!ImportFailure(user: "me", error: GitHubError.offline).message.contains("@me:"))
    }

    @Test func keepsTheDetailOfUnexpectedErrors() {
        let failure = ImportFailure(user: "me", error: GitHubError.http(418))
        #expect(failure.recovery == .retry)
        #expect(failure.message.contains("418"))
    }
}

final class LoginCLI: GitHubCLI, @unchecked Sendable {
    private let lock = NSLock()
    private var storedLogins: [String] = []
    private var storedToken: String?

    var logins: [String] {
        get { lock.withLock { storedLogins } }
        set { lock.withLock { storedLogins = newValue } }
    }

    var token: String? {
        get { lock.withLock { storedToken } }
        set { lock.withLock { storedToken = newValue } }
    }

    var isInstalled: Bool { true }
    func users() -> [String] { logins }

    func token(for user: String) throws -> String {
        guard let token, logins.contains(user) else { throw GitHubError.noToken }
        return token
    }
}
