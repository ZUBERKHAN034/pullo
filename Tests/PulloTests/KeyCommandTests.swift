import Carbon.HIToolbox
@testable import Pullo
import Testing

struct KeyCommandTests {
    private func command(_ keyCode: Int, _ characters: String = "", command: Bool = false, searching: Bool = false) -> KeyCommand? {
        KeyCommand(keyCode: keyCode, characters: characters, command: command, searching: searching)
    }

    @Test func navigationKeys() {
        #expect(command(kVK_Escape) == .close)
        #expect(command(kVK_UpArrow) == .moveUp)
        #expect(command(kVK_DownArrow) == .moveDown)
        #expect(command(kVK_Return) == .open)
        #expect(command(kVK_Tab) == .switchTab)
        #expect(command(kVK_RightArrow) == .switchTab)
        #expect(command(kVK_LeftArrow) == .previousTab)
    }

    @Test func letterShortcuts() {
        #expect(command(kVK_ANSI_C, "c") == .copyBranch)
        #expect(command(kVK_ANSI_R, "r") == .markRead)
        #expect(command(kVK_ANSI_X, "x") == nil)
    }

    @Test func commandShortcuts() {
        #expect(command(kVK_ANSI_F, "f", command: true) == .search)
        #expect(command(kVK_ANSI_Q, "q", command: true) == .quit)
        #expect(command(kVK_ANSI_2, "2", command: true) == .selectTab(2))
        #expect(command(kVK_LeftArrow, "", command: true) == .show(.pullRequests))
        #expect(command(kVK_RightArrow, "", command: true) == .show(.actions))
        #expect(command(kVK_ANSI_Comma, ",", command: true) == nil)
    }

    @Test func typingInSearchKeepsLettersInTheField() {
        #expect(command(kVK_ANSI_C, "c", searching: true) == nil)
        #expect(command(kVK_LeftArrow, searching: true) == nil)
        #expect(command(kVK_ANSI_2, "2", command: true, searching: true) == nil)
        #expect(command(kVK_DownArrow, searching: true) == .moveDown)
        #expect(command(kVK_Escape, searching: true) == .close)
    }
}
