import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage? = .general
}
