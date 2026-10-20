import SwiftUI

struct PRDragPreview: View {
    let pr: PullRequest

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.panel(.small, .semibold))
                .foregroundStyle(Color.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(pr.title)
                    .font(.panel(.label, .semibold))
                    .foregroundStyle(.white)
                Text(verbatim: "\(pr.repoName) #\(pr.number)")
                    .font(.panel(.small))
                    .foregroundStyle(.textSecondary)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 320, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.hairline))
    }
}
