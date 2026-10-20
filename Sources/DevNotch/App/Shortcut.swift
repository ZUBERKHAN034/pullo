import Carbon.HIToolbox

/// A key combination, with the symbols shown for it in the interface.
struct Shortcut {
    let keyCode: Int
    let modifiers: Int
    let symbols: String

    /// Opens or closes the panel from any app.
    static let togglePanel = Shortcut(keyCode: kVK_ANSI_P, modifiers: cmdKey | optionKey, symbols: "⌥⌘P")
}
