import SwiftUI

struct LiveCIPreview: View {
    let label: LiveCILabel

    private static let notchWidth: CGFloat = 30
    private static let notchHeight: CGFloat = 32

    private var live: LiveCI {
        var pr = PullRequest.sample
        pr.checks = CheckProgress(done: 2, total: 3)
        return LiveCI(pr: pr, othersRunning: 0, label: label)
    }

    var body: some View {
        let width = Self.notchWidth + live.wingWidth * 2
        ZStack(alignment: .top) {
            PreviewWallpaper()
            LiveCIView(live: live, notchWidth: Self.notchWidth)
                .frame(width: width, height: Self.notchHeight)
                .background(NotchShape(topRadius: 6, bottomRadius: 12).fill(Color.black))
                .scaleEffect(0.7, anchor: .top)
        }
    }
}
