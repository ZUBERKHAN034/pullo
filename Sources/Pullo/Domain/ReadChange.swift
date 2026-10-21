import Foundation

enum ReadChange: Equatable {
    case newReviewRequest
    case comments(Int)
    case reviewed(by: [String])
    case approved
    case changesRequested
    case ciFailed
    case ciPassed
    case commits(Int)
    case forcePush
}
