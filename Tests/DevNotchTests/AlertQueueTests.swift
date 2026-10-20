@testable import DevNotch
import Testing

struct AlertQueueTests {
    private func alert(_ headline: String, priority: Int = 0) -> NotchAlert {
        NotchAlert(symbol: "bell", tint: .blue, headline: headline, detail: "", priority: priority)
    }

    @Test func emptyQueueHasNothingToShow() {
        var queue = AlertQueue()
        #expect(queue.next() == nil)
    }

    @Test func oneAlertShowsAsItself() {
        var queue = AlertQueue()
        queue.append([alert("CI passed")])
        #expect(queue.next()?.headline == "CI passed")
        #expect(queue.isEmpty)
    }

    @Test func severalAlertsFoldIntoOneStackMostImportantFirst() {
        var queue = AlertQueue()
        queue.append([alert("a"), alert("b", priority: 3), alert("c"), alert("d", priority: 3)])
        let summary = queue.next()
        #expect(summary?.headline == "4 updates")
        #expect(summary?.stack.map(\.headline) == ["b", "d", "a", "c"])
        #expect(queue.isEmpty)
    }

    @Test func stacksStayUpLongerThanSingleAlerts() throws {
        var queue = AlertQueue()
        queue.append([alert("a"), alert("b")])
        let next = queue.next()
        let stack = try #require(next)
        #expect(AlertQueue.displayTime(for: stack) > AlertQueue.displayTime(for: alert("a")))
    }
}
