import Foundation

enum CIState: String, Codable, Equatable {
    case success, failure, pending

    init?(rollup: String?) {
        switch rollup {
        case "SUCCESS": self = .success
        case "FAILURE", "ERROR": self = .failure
        case "PENDING", "EXPECTED": self = .pending
        default: return nil
        }
    }
}
