import AppKit
@testable import Pullo

@MainActor
final class SpySystem: SystemActions {
    private(set) var opened: [URL] = []
    private(set) var copied: [String] = []
    private(set) var taps = 0
    private(set) var sounds: [String] = []
    private(set) var quitCount = 0
    private(set) var focusRequests = 0
    var isInFocus = false
    var fullScreen = false

    func open(_ url: URL) { opened.append(url) }
    func copy(_ text: String) { copied.append(text) }
    func tapTrackpad() { taps += 1 }
    func play(sound: String) { sounds.append(sound) }
    func quit() { quitCount += 1 }
    func requestFocusAccess() { focusRequests += 1 }
    func hasFullScreenApp(on screenFrame: NSRect) -> Bool { fullScreen }
}
