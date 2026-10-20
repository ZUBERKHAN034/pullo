import AppKit
import Carbon.HIToolbox
import SwiftUI

#if DEBUG
    @MainActor
    final class DemoTour {
        struct Cue: Encodable {
            let time: Double
            let kind: String
        }

        private let model: NotchInteraction
        private let store: PRStore
        private let source: DemoSource
        private let stage: DemoStage
        private var clockStart = CACurrentMediaTime()
        private(set) var cues: [Cue] = []
        private var forwardStateChange: ((NotchState) -> Void)?

        init(model: NotchInteraction, store: PRStore, source: DemoSource, stage: DemoStage) {
            self.model = model
            self.store = store
            self.source = source
            self.stage = stage
        }

        func run(startingAt start: Double = CACurrentMediaTime()) async {
            clockStart = start
            var previous = model.state
            forwardStateChange = model.onStateChange
            model.onStateChange = { [weak self] state in
                guard let self else { return }
                forwardStateChange?(state)
                guard state != previous else { return }
                switch state {
                case .peek: cue("peek")
                case .open: cue("open")
                case .closed: cue(previous == .open ? "close" : "peek-out")
                }
                previous = state
            }

            let screen = stage.captureRect
            let notch = CGPoint(x: screen.width / 2, y: model.geometry.notchSize.height / 2)

            let firstLoad = Task { await store.refresh() }
            stage.model.titleCard = DemoCaption(title: "DevNotch", subtitle: "Your GitHub pull requests in the Mac notch.")
            await wait(2.8)
            stage.model.titleCard = nil
            await wait(0.4)

            stage.model.cursor = CGPoint(x: screen.width * 0.62, y: screen.height * 0.82)
            stage.model.cursorVisible = true
            await moveCursor(to: CGPoint(x: notch.x + 12, y: notch.y), duration: 1.0)
            await wait(0.15)
            model.open()
            stage.model.caption = DemoCaption(title: "Works with your gh accounts", subtitle: "No new login, and no token stored.")
            await wait(0.7)
            cue("shot:00-loading")
            await firstLoad.value
            await wait(2.2)

            await moveCursor(to: CGPoint(x: screen.width * 0.66, y: screen.height * 0.78), duration: 0.8)
            model.close()
            stage.model.caption = nil
            await wait(1.0)

            await source.show(.news)
            await store.refresh()
            stage.model.caption = DemoCaption(title: "Alerts when a PR changes", subtitle: "CI, approvals, comments and review requests.")
            await wait(1.4)
            cue("shot:01-alerts")
            await wait(2.4)

            await moveCursor(to: CGPoint(x: notch.x + 12, y: notch.y), duration: 1.0)
            await wait(0.15)
            model.open()
            stage.model.caption = DemoCaption(
                title: "Hover over the notch to see your PRs",
                subtitle: "Each one shows what changed since you last looked."
            )
            await wait(0.9)
            await moveCursor(to: CGPoint(x: screen.width / 2 + 285, y: notch.y + 322), duration: 0.8)
            await wait(0.4)
            cue("shot:02-my-prs")
            press(kVK_DownArrow)
            await wait(0.7)
            press(kVK_DownArrow)
            await wait(1.4)

            press(kVK_Tab)
            stage.model.caption = DemoCaption(
                title: "Review requests",
                subtitle: "Requests sent to you are listed apart from team requests."
            )
            await wait(1.3)
            cue("shot:03-to-review")
            await wait(1.6)

            press(kVK_ANSI_2, "2", command: true)
            stage.model.caption = DemoCaption(title: "Multiple accounts", subtitle: "Each gh account has its own list.")
            await wait(1.3)
            cue("shot:04-accounts")
            await wait(1.2)
            press(kVK_ANSI_1, "1", command: true)
            await wait(1.0)

            press(kVK_ANSI_F, "f", command: true)
            stage.model.caption = DemoCaption(title: "Search with ⌘F", subtitle: "By title, repo, number, branch or author.")
            await wait(0.6)
            for character in "pay" {
                model.list.searchQuery.append(character)
                cue("type")
                await wait(0.2)
            }
            await wait(1.0)
            cue("shot:05-search")
            await wait(1.4)

            press(kVK_Escape)
            await wait(0.4)
            press(kVK_Escape)
            await moveCursor(to: CGPoint(x: screen.width * 0.3, y: screen.height * 0.7), duration: 0.9)
            stage.model.cursorVisible = false
            await wait(0.8)

            await source.show(.ciFixed)
            await store.refresh()
            stage.model.caption = DemoCaption(title: "Read-only", subtitle: "It doesn't approve, merge or store tokens.")
            await wait(1.2)
            cue("shot:06-ci-passed")
            await wait(4.0)

            stage.model.caption = nil
            stage.model.titleCard = DemoCaption(
                title: "DevNotch",
                subtitle: "Press \(Shortcut.togglePanel.symbols) to open it from any app."
            )
            cue("end-card")
            await wait(3.6)
            cue("end")
            model.onStateChange = forwardStateChange
        }

        private func cue(_ kind: String) {
            cues.append(Cue(time: CACurrentMediaTime() - clockStart, kind: kind))
        }

        private func wait(_ seconds: Double) async {
            try? await Task.sleep(for: .seconds(seconds))
        }

        private func moveCursor(to point: CGPoint, duration: Double) async {
            withAnimation(.easeInOut(duration: duration)) { stage.model.cursor = point }
            await wait(duration)
        }

        private func press(_ keyCode: Int, _ characters: String = "", command: Bool = false) {
            guard let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: command ? .command : [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: UInt16(keyCode)
            ) else { return }
            cue("key")
            _ = model.handleKey(event)
        }
    }
#endif
