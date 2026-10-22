import AppKit
@testable import Pullo
import Testing

@MainActor
struct EditMenuTests {
    @Test func textFieldsGetTheUsualShortcuts() throws {
        let app = NSApplication.shared
        let previous = app.mainMenu
        defer { app.mainMenu = previous }
        EditMenu.install(in: app)
        let items = try #require(app.mainMenu?.items.last?.submenu?.items)
        let shortcuts = items.filter { !$0.isSeparatorItem }.map { "\($0.action.map(NSStringFromSelector) ?? "")=\($0.keyEquivalent)" }
        #expect(shortcuts == ["undo:=z", "redo:=z", "cut:=x", "copy:=c", "paste:=v", "selectAll:=a", "performClose:=w"])
    }
}
