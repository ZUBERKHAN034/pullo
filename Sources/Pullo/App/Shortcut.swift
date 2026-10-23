import Carbon.HIToolbox

struct Shortcut: Equatable {
    let keyCode: Int
    let modifiers: Int
    let symbols: String

    static let togglePanel = Shortcut(keyCode: kVK_ANSI_P, modifiers: cmdKey | optionKey, symbols: "⌥⌘P")
}

enum ShortcutChoice: String, CaseIterable {
    case optionCommandP, controlOptionP, controlOptionCommandP, shiftOptionCommandP, off

    var shortcut: Shortcut? {
        switch self {
        case .optionCommandP: .togglePanel
        case .controlOptionP: Shortcut(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey, symbols: "⌃⌥P")
        case .controlOptionCommandP: Shortcut(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey | cmdKey, symbols: "⌃⌥⌘P")
        case .shiftOptionCommandP: Shortcut(keyCode: kVK_ANSI_P, modifiers: shiftKey | optionKey | cmdKey, symbols: "⇧⌥⌘P")
        case .off: nil
        }
    }

    var title: String {
        shortcut?.symbols ?? String(localized: "None")
    }
}
