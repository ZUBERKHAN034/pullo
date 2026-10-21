@testable import DevNotch
import Testing

extension NotchBehavior {
    @MainActor
    struct KeyboardTests {
        private func openWithKeyboard(mine: [PullRequest] = [.make(id: "PR_1"), .make(id: "PR_2", branch: "fix/two")]) async
            -> NotchHarness {
            let h = await NotchHarness(mine: mine)
            h.notch.toggleFromKeyboard()
            return h
        }

        @Test func arrowsMoveTheSelectionWithinTheList() async {
            let h = await openWithKeyboard()
            #expect(h.list.selectedPRID == "PR_1")
            #expect(h.notch.perform(.moveDown))
            #expect(h.list.selectedPRID == "PR_2")
            #expect(h.notch.perform(.moveDown))
            #expect(h.list.selectedPRID == "PR_2")
            #expect(h.notch.perform(.moveUp))
            #expect(h.list.selectedPRID == "PR_1")
        }

        @Test func returnOpensTheSelectedPR() async {
            let h = await openWithKeyboard()
            _ = h.notch.perform(.moveDown)
            #expect(h.notch.perform(.open))
            #expect(h.system.opened.map(\.lastPathComponent) == ["383"])
            #expect(h.notch.state == .closed)
        }

        @Test func copyingTheBranchShowsAToastThatGoesAway() async {
            let h = await openWithKeyboard()
            _ = h.notch.perform(.moveDown)
            #expect(h.notch.perform(.copyBranch))
            #expect(h.system.copied == ["fix/two"])
            #expect(h.list.toast == "Copied branch: fix/two")
            await h.clock.advance(by: .milliseconds(1800))
            #expect(h.list.toast == nil)
        }

        @Test func commandsOnASelectionNeedOne() async {
            let h = await openWithKeyboard(mine: [])
            #expect(!h.notch.perform(.open))
            #expect(!h.notch.perform(.copyBranch))
            #expect(!h.notch.perform(.markRead))
        }

        @Test func tabSwitchesBetweenMineAndReview() async {
            let h = await openWithKeyboard()
            #expect(h.list.title(of: h.list.tab) == "My PRs")
            #expect(h.notch.perform(.switchTab))
            #expect(h.list.title(of: h.list.tab) == "To review")
            #expect(h.notch.perform(.switchTab))
            #expect(h.list.title(of: h.list.tab) == "My PRs")
        }

        @Test func tabsCycleThroughFiltersToo() async {
            let h = await openWithKeyboard()
            let filter = SavedFilter(name: "API", query: "repo:acme/acme-api")
            let defaults = h.accounts.filters(for: "me")
            h.accounts.setFilters(defaults + [filter], for: "me")
            #expect(h.list.tabs.count == 3)
            _ = h.notch.perform(.previousTab)
            #expect(h.list.tab == .filter(filter.id))
            _ = h.notch.perform(.switchTab)
            #expect(h.list.tab == .filter(defaults[0].id))
        }

        @Test func numbersPickAccountsThatExist() async {
            let h = await NotchHarness(accounts: ["work", "home"])
            h.notch.toggleFromKeyboard()
            #expect(h.notch.perform(.selectAccount(2)))
            #expect(h.list.currentLogin == "home")
            #expect(!h.notch.perform(.selectAccount(3)))
            #expect(h.list.currentLogin == "home")
        }

        @Test func escapeLeavesSearchFirstThenCloses() async {
            let h = await openWithKeyboard()
            #expect(h.notch.perform(.search))
            #expect(h.list.isSearching)
            #expect(h.notch.perform(.close))
            #expect(!h.list.isSearching)
            #expect(h.notch.state == .open)
            #expect(h.notch.perform(.close))
            #expect(h.notch.state == .closed)
        }

        @Test func searchSelectsTheFirstMatchAcrossBothTabs() async {
            let h = await NotchHarness(
                mine: [.make(id: "PR_1", title: "feat: login")],
                review: [.make(id: "PR_2", title: "fix: login redirect"), .make(id: "PR_3", title: "chore: deps")]
            )
            h.notch.toggleFromKeyboard()
            _ = h.notch.perform(.search)
            h.list.searchQuery = "login"
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1", "PR_2"])
            #expect(h.list.selectedPRID == "PR_1")
        }

        @Test func quitAsksTheSystemToQuit() async {
            let h = await openWithKeyboard()
            #expect(h.notch.perform(.quit))
            #expect(h.system.quitCount == 1)
        }
    }
}
