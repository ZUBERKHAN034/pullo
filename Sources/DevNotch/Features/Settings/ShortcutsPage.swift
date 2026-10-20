import AppKit
import SwiftUI

struct ShortcutsPage: View {
    var body: some View {
        Form {
            Section {
                row("Open or close the panel", Shortcut.togglePanel.symbols)
            } header: {
                Text("Anywhere")
            } footer: {
                Text("Opening it from the keyboard selects the first PR, so you can go straight to the arrow keys.")
            }
            Section("In the panel") {
                row("Move through PRs", "↑ ↓")
                row("Open the selected PR", "↩")
                row("Switch between My PRs and To review", "⇥  or  ← →")
                row("Filter PRs", "⌘F")
                row("Copy the branch name", "C")
                row("Mark as read", "R")
                row("Switch account", "⌘1 – ⌘9")
                row("Clear the filter, or close", "esc")
                row("Quit DevNotch", "⌘Q")
            }
        }
    }

    private func row(_ action: String, _ keys: String) -> some View {
        LabeledContent(action) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
