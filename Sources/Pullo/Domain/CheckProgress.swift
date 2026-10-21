import Foundation

struct CheckProgress: Equatable {
    let done: Int
    let total: Int

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}
