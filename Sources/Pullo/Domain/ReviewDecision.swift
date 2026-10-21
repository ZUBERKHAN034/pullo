import Foundation

enum ReviewDecision: String, Codable, Equatable {
    case approved, changesRequested, reviewRequired

    init?(raw: String?) {
        switch raw {
        case "APPROVED": self = .approved
        case "CHANGES_REQUESTED": self = .changesRequested
        case "REVIEW_REQUIRED": self = .reviewRequired
        default: return nil
        }
    }
}
