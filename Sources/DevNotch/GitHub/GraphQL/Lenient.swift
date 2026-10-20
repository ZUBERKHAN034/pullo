import Foundation
import OSLog

struct Lenient<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        do {
            value = try T(from: decoder)
        } catch {
            Logger.github
                .debug("Skipped a \(String(describing: T.self), privacy: .public): \(error.localizedDescription, privacy: .public)")
            value = nil
        }
    }
}
