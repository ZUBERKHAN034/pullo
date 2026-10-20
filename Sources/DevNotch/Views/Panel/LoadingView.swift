import SwiftUI

struct LoadingView: View {
    private static let messages = [
        "Waking up GitHub…",
        "Counting your PRs…",
        "Checking CI…",
        "Finding review requests…",
        "Reading comments…",
    ]
    private static let rows: [(title: CGFloat, subtitle: CGFloat, tag: Bool)] = [
        (230, 150, true), (190, 170, false), (260, 120, true), (170, 140, false),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                TimelineView(.periodic(from: .now, by: 1.6)) { context in
                    let index = Int(context.date.timeIntervalSinceReferenceDate / 1.6) % Self.messages.count
                    Text(Self.messages[index])
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .id(index)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                        .animation(Motion.navigate, value: index)
                }
                .frame(height: 18)
                .clipped()
            }
            .padding(.top, 6)

            VStack(spacing: 2) {
                ForEach(Self.rows.indices, id: \.self) { index in
                    SkeletonRow(title: Self.rows[index].title, subtitle: Self.rows[index].subtitle, tag: Self.rows[index].tag)
                        .opacity(1 - Double(index) * 0.18)
                }
            }
            .shimmering()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SkeletonRow: View {
    let title: CGFloat
    let subtitle: CGFloat
    let tag: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle().frame(width: 12, height: 12).frame(width: 18)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).frame(width: title, height: 9)
                RoundedRectangle(cornerRadius: 3).frame(width: subtitle, height: 7)
            }
            Spacer()
            if tag { Capsule().frame(width: 52, height: 14) }
            RoundedRectangle(cornerRadius: 3).frame(width: 24, height: 8)
        }
        .foregroundStyle(.white.opacity(0.08))
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}
