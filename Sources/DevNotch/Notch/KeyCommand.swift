import Carbon.HIToolbox

/// What a key press means in the panel, decided apart from what it does.
enum KeyCommand: Equatable {
    case quit, search, close
    case moveUp, moveDown, open
    case switchTab, selectAccount(Int), copyBranch, markRead

    init?(keyCode: Int, characters: String, command: Bool, searching: Bool) {
        if command {
            switch characters {
            case "q": self = .quit
            case "f": self = .search
            default:
                guard !searching, let number = Int(characters), (1...9).contains(number) else { return nil }
                self = .selectAccount(number)
            }
            return
        }
        switch keyCode {
        case kVK_Escape: self = .close
        case kVK_UpArrow: self = .moveUp
        case kVK_DownArrow: self = .moveDown
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .open
        default:
            // While typing a search, everything else belongs to the text field.
            guard !searching else { return nil }
            switch (keyCode, characters) {
            case (kVK_Tab, _), (kVK_LeftArrow, _), (kVK_RightArrow, _): self = .switchTab
            case (_, "c"): self = .copyBranch
            case (_, "r"): self = .markRead
            default: return nil
            }
        }
    }
}
