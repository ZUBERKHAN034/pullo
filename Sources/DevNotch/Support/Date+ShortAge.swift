import Foundation

extension Date {
    var shortAge: String {
        let seconds = max(0, Int(Date().timeIntervalSince(self)))
        switch seconds {
        case ..<60: return String(localized: "now")
        case ..<3600: return "\(seconds / 60)m"
        case ..<86400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86400)d"
        }
    }
}
