import Foundation
@testable import Pullo
import Testing

extension NotchBehavior {
    @MainActor
    struct ActionsKeyboardTests {
        private func openOnActions(_ runs: [WorkflowRun] = [
            .make(id: 1, state: .running, createdAt: Date(timeIntervalSince1970: 300)),
            .make(id: 2, state: .passed, createdAt: Date(timeIntervalSince1970: 200)),
            .make(id: 3, state: .failed, createdAt: Date(timeIntervalSince1970: 100)),
        ]) async -> NotchHarness {
            let h = await NotchHarness(runSource: StubRunSource(pushed: ["acme/api"], runs: ["acme/api": runs]))
            await h.runs.refresh()
            h.notch.show(.actions)
            h.notch.toggleFromKeyboard()
            return h
        }

        @Test func openingWithTheKeyboardSelectsTheFirstRun() async {
            let h = await openOnActions()
            #expect(h.actions.selectedRunID == 1)
        }

        @Test func arrowsMoveThroughRunningAndRecentRuns() async {
            let h = await openOnActions()
            #expect(h.notch.perform(.moveDown))
            #expect(h.actions.selectedRunID == 2)
            #expect(h.notch.perform(.moveDown))
            #expect(h.notch.perform(.moveDown))
            #expect(h.actions.selectedRunID == 3)
            #expect(h.notch.perform(.moveUp))
            #expect(h.actions.selectedRunID == 2)
        }

        @Test func returnOpensTheRunThenGitHub() async {
            let h = await openOnActions()
            _ = h.notch.perform(.moveDown)
            #expect(h.notch.perform(.open))
            #expect(h.actions.openedRun?.id == 2)
            #expect(h.system.opened.isEmpty)
            #expect(!h.notch.perform(.moveDown))
            #expect(h.notch.perform(.open))
            #expect(h.system.opened.map(\.absoluteString) == ["https://github.com/acme/api/actions/runs/1"])
            #expect(h.notch.state == .closed)
        }

        @Test func escapeGoesBackAndKeepsTheSelection() async {
            let h = await openOnActions()
            _ = h.notch.perform(.moveDown)
            _ = h.notch.perform(.open)
            #expect(h.notch.perform(.close))
            #expect(h.actions.openedRun == nil)
            #expect(h.actions.selectedRunID == 2)
            #expect(h.notch.state == .open)
        }

        @Test func switchingToActionsFromTheKeyboardSelectsARun() async {
            let h = await NotchHarness(runSource: StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 9)]]))
            await h.runs.refresh()
            h.notch.toggleFromKeyboard()
            #expect(h.notch.perform(.show(.actions)))
            #expect(h.actions.selectedRunID == 9)
            h.notch.close()
            #expect(h.actions.selectedRunID == nil)
        }

        @Test func returnWithoutARunDoesNothing() async {
            let h = await openOnActions([])
            #expect(!h.notch.perform(.moveDown))
            #expect(!h.notch.perform(.open))
            #expect(h.notch.state == .open)
        }

        @Test func tabKeyCyclesTheActionsTabs() async {
            let h = await openOnActions()
            let first = h.actions.tab?.id
            #expect(h.notch.perform(.switchTab))
            #expect(h.actions.tab?.id != first)
            #expect(h.notch.perform(.previousTab))
            #expect(h.actions.tab?.id == first)
        }
    }
}
