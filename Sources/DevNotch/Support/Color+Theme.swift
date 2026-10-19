import SwiftUI

extension Color {
    static let unread = Color(red: 0.38, green: 0.64, blue: 1)
    /// Supporting text: repo, author, age. Bright enough to read at a glance on the black panel.
    static let secondaryText = Color.white.opacity(0.6)
    /// Labels that only frame other content: section headers, key hints, counts.
    static let tertiaryText = Color.white.opacity(0.48)
}
