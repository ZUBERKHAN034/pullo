import Carbon.HIToolbox

struct Shortcut {
    let keyCode: Int
    let modifiers: Int
    let symbols: String

    static let togglePanel = Shortcut(keyCode: kVK_ANSI_P, modifiers: cmdKey | optionKey, symbols: "⌥⌘P")
}
