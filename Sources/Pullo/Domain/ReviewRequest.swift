import Foundation

enum ReviewRequest: Equatable {
    case direct
    case team([String])
}
