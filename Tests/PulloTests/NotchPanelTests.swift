import AppKit
@testable import Pullo
import SwiftUI
import Testing

@MainActor
struct NotchPanelTests {
    @Test func staysDarkInLightMode() {
        let panel = NotchPanel(rootView: EmptyView())
        #expect(panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
    }
}
