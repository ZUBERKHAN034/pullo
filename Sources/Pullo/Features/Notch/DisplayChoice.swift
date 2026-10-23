import AppKit

enum DisplayChoice: String, CaseIterable {
    case builtIn, main, pointer

    var title: String {
        switch self {
        case .builtIn: String(localized: "Built-in display")
        case .main: String(localized: "Main display")
        case .pointer: String(localized: "Display with the pointer")
        }
    }

    struct Candidate: Equatable {
        var frame: NSRect
        var hasNotch = false
        var isBuiltIn = false
    }

    func pick(among screens: [Candidate], pointer: NSPoint) -> Int? {
        guard !screens.isEmpty else { return nil }
        switch self {
        case .builtIn:
            return screens.firstIndex(where: \.hasNotch) ?? screens.firstIndex(where: \.isBuiltIn) ?? 0
        case .main:
            return 0
        case .pointer:
            return screens.firstIndex { $0.frame.insetBy(dx: 0, dy: -1).contains(pointer) }
                ?? DisplayChoice.builtIn.pick(among: screens, pointer: pointer)
        }
    }

    @MainActor
    func screen(pointer: NSPoint = NSEvent.mouseLocation) -> NSScreen? {
        let screens = NSScreen.screens
        let candidates = screens.map { screen in
            Candidate(frame: screen.frame, hasNotch: screen.safeAreaInsets.top > 0, isBuiltIn: screen.isBuiltIn)
        }
        return pick(among: candidates, pointer: pointer).map { screens[$0] }
    }
}

extension NSScreen {
    fileprivate var isBuiltIn: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
        return CGDisplayIsBuiltin(number.uint32Value) != 0
    }
}
