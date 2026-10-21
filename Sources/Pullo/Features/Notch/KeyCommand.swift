import Carbon.HIToolbox

enum KeyCommand: Equatable {
    case quit, search, close
    case moveUp, moveDown, open
    case switchTab, previousTab, selectAccount(Int), copyBranch, markRead
    case show(PanelArea)

    var worksEverywhere: Bool {
        switch self {
        case .quit, .close, .selectAccount, .show: true
        default: false
        }
    }

    init?(keyCode: Int, characters: String, command: Bool, searching: Bool) {
        if command {
            switch keyCode {
            case kVK_LeftArrow: self = .show(.pullRequests); return
            case kVK_RightArrow: self = .show(.actions); return
            default: break
            }
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
            guard !searching else { return nil }
            switch (keyCode, characters) {
            case (kVK_Tab, _), (kVK_RightArrow, _): self = .switchTab
            case (kVK_LeftArrow, _): self = .previousTab
            case (_, "c"): self = .copyBranch
            case (_, "r"): self = .markRead
            default: return nil
            }
        }
    }
}
