import AppKit
import SwiftUI

enum Announcement {
    @MainActor
    static func post(_ text: String) {
        guard !text.isEmpty, let app = NSApp else { return }
        NSAccessibility.post(element: app, notification: .announcementRequested, userInfo: [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }
}

extension View {
    func announcing(_ text: String) -> some View {
        task(id: text) { Announcement.post(text) }
    }
}
