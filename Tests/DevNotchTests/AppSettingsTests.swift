@testable import DevNotch
import Foundation
import Testing

@MainActor
struct AppSettingsTests {
    @Test func thePanelIsSolidUntilGlassIsChosen() {
        let scratch = ScratchDefaults()
        #expect(AppSettings(defaults: scratch.defaults).panelStyle == .solid)
    }

    @Test func theChosenPanelStyleIsRemembered() {
        let scratch = ScratchDefaults()
        AppSettings(defaults: scratch.defaults).panelStyle = .glass
        #expect(AppSettings(defaults: scratch.defaults).panelStyle == .glass)
    }

    @Test func soundsChosenPerKindAreRemembered() {
        let scratch = ScratchDefaults()
        AppSettings(defaults: scratch.defaults).categorySounds = [.ciFailed: "Basso", .ciPassed: ""]
        let reloaded = AppSettings(defaults: scratch.defaults)
        #expect(reloaded.categorySounds == [.ciFailed: "Basso", .ciPassed: ""])
        #expect(reloaded.sound(for: .ciPassed) == nil)
    }
}
