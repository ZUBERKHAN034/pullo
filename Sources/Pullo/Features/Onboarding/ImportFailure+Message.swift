import Foundation

extension ImportFailure {
    var message: String { "@\(user): \(reason)" }
}
