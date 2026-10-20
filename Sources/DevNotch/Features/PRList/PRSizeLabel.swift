import SwiftUI

struct PRSizeLabel: View {
    let size: PRSize

    var body: some View {
        HStack(spacing: 3) {
            Text(verbatim: "+" + Self.compact(size.additions)).foregroundStyle(Color.green.opacity(0.6))
            Text(verbatim: "−" + Self.compact(size.deletions)).foregroundStyle(Color.red.opacity(0.6))
        }
        .font(.panel(.caption, .medium).monospacedDigit())
        .fixedSize()
        .hint(String(localized: "+\(size.additions) −\(size.deletions) · \(size.changedFiles) files changed"), edge: .leading)
        .accessibilityLabel(String(localized: "\(size.additions) lines added, \(size.deletions) removed, \(size.changedFiles) files"))
    }

    static func compact(_ value: Int, locale: Locale = .current) -> String {
        guard value >= 1000 else { return "\(value)" }
        return (Double(value) / 1000).formatted(.number.precision(.fractionLength(0...1)).locale(locale)) + "k"
    }
}
