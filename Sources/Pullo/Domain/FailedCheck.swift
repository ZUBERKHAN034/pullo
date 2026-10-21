import Foundation

struct FailedCheck: Identifiable, Equatable {
    let name: String
    let url: URL?

    var id: String { "\(name)|\(url?.absoluteString ?? "")" }
}
