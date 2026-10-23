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
    func hasFullScreenApp(on screenFrame: NSRect) -> Bool
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

    func hasFullScreenApp(on screenFrame: NSRect) -> Bool {
        guard NSApp.currentSystemPresentationOptions.contains(.fullScreen),
              let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
              as? [[String: Any]]
        else { return false }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height
        let screen = CGRect(
            x: screenFrame.minX,
            y: primaryHeight - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )
        return windows.contains { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == front.processIdentifier,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary)
            else { return false }
            return screen.contains(CGPoint(x: bounds.midX, y: bounds.midY)) && bounds.width >= screen.width
        }
    }
}

extension EnvironmentValues {
    @Entry var system: any SystemActions = LiveSystemActions()
}
