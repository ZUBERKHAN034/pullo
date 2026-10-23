import Foundation

extension Date {
    var shortAge: String { shortAge(at: Date()) }

    func shortAge(at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(self)))
        switch seconds {
        case ..<60: return String(localized: "now")
        case ..<3600: return String(localized: "\(seconds / 60)m")
        case ..<86400: return String(localized: "\(seconds / 3600)h")
        default: return String(localized: "\(seconds / 86400)d")
        }
    }
}
