import AppKit
@testable import Pullo
import Testing

struct DisplayChoiceTests {
    private let external = DisplayChoice.Candidate(frame: NSRect(x: 0, y: 0, width: 2560, height: 1440))
    private let laptop = DisplayChoice.Candidate(
        frame: NSRect(x: 2560, y: 0, width: 1512, height: 982),
        hasNotch: true,
        isBuiltIn: true
    )
    private let olderLaptop = DisplayChoice.Candidate(frame: NSRect(x: -1440, y: 0, width: 1440, height: 900), isBuiltIn: true)

    @Test func builtInPrefersTheNotchThenTheLaptopScreen() {
        #expect(DisplayChoice.builtIn.pick(among: [external, laptop], pointer: .zero) == 1)
        #expect(DisplayChoice.builtIn.pick(among: [external, olderLaptop], pointer: .zero) == 1)
        #expect(DisplayChoice.builtIn.pick(among: [external], pointer: .zero) == 0)
    }

    @Test func mainIsTheScreenWithTheMenuBar() {
        #expect(DisplayChoice.main.pick(among: [external, laptop], pointer: NSPoint(x: 3000, y: 500)) == 0)
    }

    @Test func pointerFollowsTheScreenUnderIt() {
        #expect(DisplayChoice.pointer.pick(among: [external, laptop], pointer: NSPoint(x: 3000, y: 500)) == 1)
        #expect(DisplayChoice.pointer.pick(among: [external, laptop], pointer: NSPoint(x: 100, y: 1440)) == 0)
        #expect(DisplayChoice.pointer.pick(among: [external, laptop], pointer: NSPoint(x: 9000, y: 9000)) == 1)
    }

    @Test func noScreensMeansNoChoice() {
        #expect(DisplayChoice.pointer.pick(among: [], pointer: .zero) == nil)
    }
}

@MainActor
struct FirstRunSettingsTests {
    @Test func defaultsKeepTodaysBehavior() {
        let scratch = ScratchDefaults()
        let settings = AppSettings(defaults: scratch.defaults)
        #expect(settings.display == .builtIn)
        #expect(settings.shortcut.shortcut == .togglePanel)
        #expect(!settings.holdsAlertsInFullScreen)
    }

    @Test func choicesAreRemembered() {
        let scratch = ScratchDefaults()
        let settings = AppSettings(defaults: scratch.defaults)
        settings.display = .pointer
        settings.shortcut = .controlOptionP
        settings.holdsAlertsInFullScreen = true
        let reloaded = AppSettings(defaults: scratch.defaults)
        #expect(reloaded.display == .pointer)
        #expect(reloaded.shortcut.shortcut?.symbols == "⌃⌥P")
        #expect(reloaded.holdsAlertsInFullScreen)
    }

    @Test func theShortcutCanBeTurnedOff() {
        #expect(ShortcutChoice.off.shortcut == nil)
        #expect(Set(ShortcutChoice.allCases.compactMap(\.shortcut?.symbols)).count == ShortcutChoice.allCases.count - 1)
    }
}

extension NotchBehavior {
    @MainActor
    struct FullScreenTests {
        @Test func alertsShowOverFullScreenAppsUnlessAskedToHold() async {
            let h = await NotchHarness()
            h.system.fullScreen = true
            h.peeks.enqueue(h.alert())
            #expect(h.notch.state == .peek)
        }

        @Test func heldAlertsShowTogetherAfterLeavingFullScreen() async {
            let h = await NotchHarness()
            h.settings.holdsAlertsInFullScreen = true
            h.system.fullScreen = true
            h.peeks.enqueue(h.alert("first"))
            h.peeks.enqueue(h.alert("second"))
            #expect(h.notch.state == .closed)
            await h.clock.advance(by: .seconds(30))
            #expect(h.notch.state == .closed)

            h.system.fullScreen = false
            await h.clock.advance(by: .seconds(5))
            #expect(h.notch.state == .peek)
            #expect(h.notch.peekAlert?.stack.map(\.headline) == ["first", "second"])
            #expect(h.notch.peekAlert?.note == "While an app was full screen")
        }

        @Test func aTestAlertShowsEvenInFullScreen() async {
            let h = await NotchHarness()
            h.settings.holdsAlertsInFullScreen = true
            h.system.fullScreen = true
            h.notch.previewAlert()
            await h.clock.advance(by: .milliseconds(450))
            #expect(h.notch.state == .peek)
        }
    }
}
