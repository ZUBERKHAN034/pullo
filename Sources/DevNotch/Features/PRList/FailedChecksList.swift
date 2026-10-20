import SwiftUI

struct FailedChecksList: View {
    @Environment(NotchInteraction.self) private var notch
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if pr.failedChecks.isEmpty {
                Text("GitHub didn't say which checks failed.")
                    .font(.panel(.small))
                    .foregroundStyle(.textSecondary)
            }
            ForEach(pr.failedChecks) { check in
                Button {
                    if let url = check.url { notch.openInBrowser(url) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.panel(.micro))
                            .foregroundStyle(.red)
                        Text(check.name)
                            .font(.panel(.small, .medium))
                            .foregroundStyle(.textStrong)
                            .lineLimit(1)
                        if check.url != nil {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hint(check.url == nil ? "No link for this check" : "Open the check log")
            }
        }
    }
}
