import SwiftUI

struct FailedChecksList: View {
    let pr: PullRequest
    let model: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if pr.failedChecks.isEmpty {
                Text("GitHub didn't say which checks failed.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
            }
            ForEach(pr.failedChecks) { check in
                Button {
                    if let url = check.url { model.openInBrowser(url) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                        Text(check.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                        if check.url != nil {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.tertiaryText)
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
