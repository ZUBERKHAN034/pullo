import SwiftUI

struct PRList: View {
    let sections: [PRSection]
    @ObservedObject var model: NotchViewModel
    @ObservedObject var tracker: ReadTracker
    @State private var appeared = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Group {
                            switch entry {
                            case .header(let title, let count):
                                HStack(spacing: 6) {
                                    Text(title.uppercased())
                                    Text("\(count)").foregroundStyle(.textTertiary)
                                }
                                .font(.panel(.micro, .bold))
                                .kerning(0.6)
                                .foregroundStyle(.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.top, index == 0 ? 2 : 10)
                                .padding(.bottom, 2)
                            case .row(let pr, let kind):
                                PRRow(
                                    pr: pr,
                                    kind: kind,
                                    selected: model.selectedPRID == pr.id,
                                    unreadReasons: tracker.reasons(for: pr),
                                    model: model
                                )
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .blur(radius: appeared ? 0 : 3)
                        .animation(
                            Motion.reveal.delay(0.06 + Double(min(index, 8)) * 0.03),
                            value: appeared
                        )
                    }
                }
            }
            .onChange(of: model.selectedPRID) { _, id in
                guard let id else { return }
                withAnimation(Motion.navigate) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .onAppear { appeared = true }
    }

    private enum Entry: Identifiable {
        case header(String, Int)
        case row(PullRequest, PRTab)

        var id: String {
            switch self {
            case .header(let title, _): "header|\(title)"
            case .row(let pr, _): pr.id
            }
        }
    }

    private var entries: [Entry] {
        sections.flatMap { section -> [Entry] in
            let rows = section.prs.map { Entry.row($0, section.kind) }
            guard let title = section.title else { return rows }
            return [.header(title, section.prs.count)] + rows
        }
    }
}
