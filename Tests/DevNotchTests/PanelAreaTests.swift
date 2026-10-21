import AppKit
@testable import DevNotch
import Testing

extension NotchBehavior {
    @MainActor
    struct PanelAreaTests {
        @Test func opensOnPullRequestsAndSwitchesWithTheKeyboard() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1")])
            h.notch.open()
            #expect(h.notch.area == .pullRequests)
            #expect(h.notch.perform(.show(.actions)))
            #expect(h.notch.area == .actions)
            #expect(h.notch.perform(.show(.pullRequests)))
            #expect(h.notch.area == .pullRequests)
        }

        @Test func pullRequestKeysDoNothingInActions() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1")])
            h.notch.open()
            h.notch.show(.actions)
            #expect(!h.notch.perform(.moveDown))
            #expect(!h.notch.perform(.search))
            #expect(h.list.selectedPR == nil)
            #expect(!h.list.isSearching)
            #expect(h.notch.perform(.close))
            #expect(h.notch.state == .closed)
        }

        @Test func switchingToActionsEndsTheSearch() async {
            let h = await NotchHarness()
            h.notch.open()
            h.list.startSearch()
            h.notch.show(.actions)
            #expect(!h.list.isSearching)
        }

        @Test func theSwitcherBelowThePanelKeepsItOpen() async {
            let h = await NotchHarness()
            h.notch.open()
            let panel = h.notch.layout.size(for: .open)
            let screen = h.notch.geometry.screenFrame
            let switcher = NSPoint(x: screen.midX, y: screen.maxY - panel.height - NotchLayout.switcherSpace / 2)
            h.notch.mouseMoved(to: switcher)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
        }
    }
}
