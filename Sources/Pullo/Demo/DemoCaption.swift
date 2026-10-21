import AppKit
import SwiftUI

#if DEBUG
    struct DemoCaption: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
    }
#endif
