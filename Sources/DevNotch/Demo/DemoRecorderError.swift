import AppKit
import AVFoundation
import ScreenCaptureKit

#if DEBUG
    enum DemoRecorderError: LocalizedError {
        case notAllowed, nothingToCapture

        var errorDescription: String? {
            switch self {
            case .notAllowed:
                "No permission to record the screen. Allow DevNotch in System Settings → Privacy & Security → Screen Recording and run it again."
            case .nothingToCapture:
                "Couldn't find the screen or DevNotch's windows to record."
            }
        }
    }
#endif
