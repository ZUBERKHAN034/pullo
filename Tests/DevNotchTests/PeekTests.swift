import AppKit
@testable import DevNotch
import Testing

extension NotchBehavior {
    @MainActor
    struct PeekTests {
        @Test func anAlertDropsOutThenGoesAway() async {
            let h = await NotchHarness()
            h.notch.enqueue(h.alert())
            #expect(h.notch.state == .peek)
            #expect(h.notch.peekAlert?.headline == "CI passed")
            await h.clock.advance(by: .milliseconds(4499))
            #expect(h.notch.state == .peek)
            await h.clock.advance(by: .milliseconds(1))
            #expect(h.notch.state == .closed)
        }

        @Test func alertsTapTheTrackpadAndPlayTheChosenSound() async {
            let h = await NotchHarness()
            h.settings.sound = "Pop"
            h.notch.enqueue(h.alert())
            #expect(h.system.taps == 1)
            #expect(h.system.sounds == ["Pop"])
        }

        @Test func silentAlertsStaySilent() async {
            let h = await NotchHarness()
            h.settings.haptics = false
            h.settings.sound = nil
            h.notch.enqueue(h.alert())
            #expect(h.system.taps == 0)
            #expect(h.system.sounds.isEmpty)
        }

        @Test func alertsArrivingDuringAPeekShowNext() async {
            let h = await NotchHarness()
            h.notch.enqueue(h.alert("first"))
            h.notch.enqueue(h.alert("second"))
            #expect(h.notch.peekAlert?.headline == "first")
            await h.clock.advance(by: .milliseconds(4500))
            #expect(h.notch.state == .closed)
            await h.clock.advance(by: .milliseconds(500))
            #expect(h.notch.state == .peek)
            #expect(h.notch.peekAlert?.headline == "second")
        }

        @Test func alertsArrivingTogetherStackAndStayLonger() async {
            let h = await NotchHarness()
            h.notch.enqueue([h.alert("low"), h.alert("high", priority: 2)])
            #expect(h.notch.peekAlert?.stack.map(\.headline) == ["high", "low"])
            await h.clock.advance(by: .milliseconds(4500))
            #expect(h.notch.state == .peek)
            await h.clock.advance(by: .milliseconds(1500))
            #expect(h.notch.state == .closed)
        }

        @Test func alertsWhileOpenAreDropped() async {
            let h = await NotchHarness()
            h.notch.open()
            h.notch.enqueue(h.alert())
            h.notch.close()
            await h.clock.advance(by: .seconds(1))
            #expect(h.notch.state == .closed)
            #expect(h.notch.peekAlert == nil)
        }

        @Test func hoveringHoldsThePeekAndLeavingLetsItGo() async {
            let h = await NotchHarness()
            h.notch.enqueue(h.alert())
            h.notch.mouseMoved(to: h.inside(.peek))
            await h.clock.advance(by: .seconds(10))
            #expect(h.notch.state == .peek)
            h.notch.mouseMoved(to: h.outside)
            await h.clock.advance(by: .milliseconds(1499))
            #expect(h.notch.state == .peek)
            await h.clock.advance(by: .milliseconds(1))
            #expect(h.notch.state == .closed)
        }

        @Test func tappingAPRAlertOpensItAndMarksItRead() async {
            let pr = PullRequest.make(id: "PR_1")
            let h = await NotchHarness(mine: [pr])
            let changed = PullRequest.make(id: "PR_1", comments: ["c1"])
            h.tracker.sync(account: "me", prs: [changed])
            #expect(h.tracker.isUnread(changed))

            var alert = h.alert()
            alert.pr = changed
            h.notch.enqueue(alert)
            h.notch.tapPeek(alert)
            #expect(h.system.opened == [changed.url])
            #expect(!h.tracker.isUnread(changed))
            #expect(h.notch.state == .closed)
        }

        @Test func mutedCategoriesNeverAlert() async {
            let pr = PullRequest.make()
            let h = await NotchHarness(mine: [pr])
            h.settings.toggle(AlertCategory(PREvent(kind: .ciPassed, pr: pr, actor: nil)))
            h.notch.enqueue(events: [PREvent(kind: .ciPassed, pr: pr, actor: nil)])
            #expect(h.notch.state == .closed)
        }

        @Test func alertsStayHiddenDuringFocus() async {
            let h = await NotchHarness()
            h.system.isInFocus = true
            h.notch.enqueue(h.alert())
            #expect(h.notch.state == .closed)
            #expect(h.system.taps == 0)
            #expect(h.system.sounds.isEmpty)
        }

        @Test func alertsHeldBackByFocusDoNotPileUpForLater() async {
            let h = await NotchHarness()
            h.system.isInFocus = true
            h.notch.enqueue(h.alert("during focus"))
            h.system.isInFocus = false
            h.notch.enqueue(h.alert("after focus"))
            #expect(h.notch.peekAlert?.headline == "after focus")
            #expect(h.notch.peekAlert?.stack.isEmpty == true)
        }

        @Test func aTestAlertShowsEvenDuringFocus() async {
            let h = await NotchHarness()
            h.system.isInFocus = true
            h.notch.previewAlert()
            await h.clock.advance(by: .milliseconds(450))
            #expect(h.notch.state == .peek)
        }
    }
}
