import AppKit
import SwiftUI

@MainActor
protocol SystemActions {
    func open(_ url: URL)
    func copy(_ text: String)
    func tapTrackpad()
    func play(sound: String)
    func quit()
}

struct LiveSystemActions: SystemActions {
    func open(_ url: URL) {
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
}

extension EnvironmentValues {
    @Entry var system: any SystemActions = LiveSystemActions()
}
