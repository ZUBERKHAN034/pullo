import AppKit
import Observation
import SwiftUI

#if DEBUG
    @MainActor
    @Observable
    final class DemoStageModel {
        var caption: DemoCaption?
        var titleCard: DemoCaption?
        var cursor: CGPoint
        var cursorVisible = false

        init(cursor: CGPoint) {
            self.cursor = cursor
        }
    }
#endif
