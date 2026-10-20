import AppKit
@testable import DevNotch
import Testing

extension NotchBehavior {
    @MainActor
    struct NotchInteractionTests {
        @Test func hoveringOpensAfterAShortWait() async {
            let h = await NotchHarness()
            h.notch.mouseMoved(to: h.inside(.closed))
            await h.clock.advance(by: .milliseconds(79))
            #expect(h.notch.state == .closed)
            await h.clock.advance(by: .milliseconds(1))
            #expect(h.notch.state == .open)
        }

        @Test func passingOverTheNotchDoesNotOpenIt() async {
            let h = await NotchHarness()
            h.notch.mouseMoved(to: h.inside(.closed))
            await h.clock.advance(by: .milliseconds(40))
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .closed)
        }

        @Test func leavingTheOpenPanelClosesIt() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .milliseconds(199))
            #expect(h.notch.state == .open)
            await h.clock.advance(by: .milliseconds(1))
            #expect(h.notch.state == .closed)
        }

        @Test func comingBackBeforeTheDelayKeepsItOpen() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .milliseconds(100))
            h.notch.mouseMoved(to: h.inside(.open))
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
        }

        @Test func clickingOutsideCloses() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.mouseDown(at: h.outside)
            #expect(h.notch.state == .closed)
        }

        @Test func closingUnderThePointerDoesNotReopenUntilItLeaves() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.close(pointerStaysOver: true)
            h.notch.mouseMoved(to: h.inside(.closed))
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .closed)

            h.notch.mouseMoved(to: h.outside)
            h.notch.mouseMoved(to: h.inside(.closed))
            await h.clock.advance(by: .milliseconds(80))
            #expect(h.notch.state == .open)
        }

        @Test func keyboardOpenStaysOpenWhenThePointerIsAway() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1"), .make(id: "PR_2")])
            h.notch.toggleFromKeyboard()
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .open)
            #expect(h.list.selectedPRID == "PR_1")
        }

        @Test func pointerTakesOverFromTheKeyboardOnceItEnters() async {
            let h = await NotchHarness()
            h.notch.toggleFromKeyboard()
            h.notch.mouseMoved(to: h.inside(.open))
            #expect(!h.list.keyboardMode)
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .milliseconds(200))
            #expect(h.notch.state == .closed)
        }

        @Test func closingResetsSearchAndSelection() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1")])
            h.notch.toggleFromKeyboard()
            h.list.startSearch()
            h.list.searchQuery = "canal"
            h.notch.close()
            #expect(!h.list.isSearching)
            #expect(h.list.searchQuery.isEmpty)
            #expect(h.list.selectedPRID == nil)
            #expect(!h.list.keyboardMode)
        }
    }
}
