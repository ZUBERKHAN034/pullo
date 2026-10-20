import AppKit
import SwiftUI

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage? = .general
}
