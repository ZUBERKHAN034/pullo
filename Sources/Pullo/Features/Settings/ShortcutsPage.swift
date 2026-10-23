import AppKit
import SwiftUI

struct ShortcutsPage: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Open or close the panel", selection: $settings.shortcut) {
                    ForEach(ShortcutChoice.allCases, id: \.self) { choice in
                        if choice == .off { Divider() }
                        Text(choice.title).tag(choice)
                    }
                }
                if settings.shortcutUnavailable {
                    Label("Another app already uses this shortcut. Pick another one.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Anywhere")
            } footer: {
                Text("Opening it from the keyboard selects the first PR, so you can go straight to the arrow keys.")
            }
            Section("In the panel") {
                row("Move through PRs", "↑ ↓")
                row("Open the selected PR", "↩")
                row("Switch tabs", String(localized: "⇥  or  ← →"))
                row("Search PRs", "⌘F")
                row("Switch between pull requests and Actions", "⌘← ⌘→")
                row("Copy the branch name", "C")
                row("Mark as read", "R")
                row("Go to a tab", "⌘1 – ⌘9")
                row("Clear the search, or close", "esc")
                row("Open Settings", "⌘,")
                row("Quit Pullo", "⌘Q")
            }
        }
    }

    private func row(_ action: LocalizedStringKey, _ keys: String) -> some View {
        LabeledContent(action) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
