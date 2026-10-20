import AppKit
import SwiftUI

@MainActor
final class DemoStageModel: ObservableObject {
    @Published var caption: DemoCaption?
    @Published var titleCard: DemoCaption?
    @Published var cursor: CGPoint
    @Published var cursorVisible = false

    init(cursor: CGPoint) {
        self.cursor = cursor
    }
}
