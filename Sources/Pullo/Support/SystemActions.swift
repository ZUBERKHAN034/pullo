import AppKit
import Intents
import SwiftUI

@MainActor
protocol SystemActions {
    func open(_ url: URL)
    func copy(_ text: String)
    func tapTrackpad()
    func play(sound: String)
    func quit()
    var isInFocus: Bool { get }
    func requestFocusAccess()
}

struct LiveSystemActions: SystemActions {
    func open(_ url: URL) {
        guard url.isWeb else { return }
        NSWorkspace.shared.open(url)
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func tapTrackpad() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    func play(sound: String) {
        guard let player = NSSound(named: sound) else { return }
        player.stop()
        player.play()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    var isInFocus: Bool {
        let center = INFocusStatusCenter.default
        return center.authorizationStatus == .authorized && center.focusStatus.isFocused == true
    }

    func requestFocusAccess() {
        guard INFocusStatusCenter.default.authorizationStatus == .notDetermined else { return }
        INFocusStatusCenter.default.requestAuthorization { _ in }
    }
}

extension EnvironmentValues {
    @Entry var system: any SystemActions = LiveSystemActions()
}
