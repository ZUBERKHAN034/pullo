import SwiftUI

struct KeyboardHints: View {
    enum Context {
        case pullRequests(searching: Bool)
        case runs
        case run
    }

    let context: Context

    var body: some View {
        HStack(spacing: 12) {
            switch context {
            case .pullRequests(let searching):
                hint("↑↓", String(localized: "navigate"))
                hint("↩", String(localized: "open"))
                if searching {
                    hint("esc", String(localized: "clear search"))
                } else {
                    hint("⌘F", String(localized: "search"))
                    hint("esc", String(localized: "close"))
                }
            case .runs:
                hint("↑↓", String(localized: "navigate"))
                hint("↩", String(localized: "open"))
                hint("esc", String(localized: "close"))
            case .run:
                hint("↩", String(localized: "open on GitHub"))
                hint("esc", String(localized: "back"))
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            KeyCap(key: key)
            Text(label)
                .font(.panel(.caption, .medium))
                .foregroundStyle(.textTertiary)
        }
    }
}
