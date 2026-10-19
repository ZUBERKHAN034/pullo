import SwiftUI

/// A status next to a PR: a tinted symbol and a short word, no capsule, so it reads as metadata and not a button.
struct Tag: View {
    let text: String
    let tint: Color
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(tint)
    }
}
