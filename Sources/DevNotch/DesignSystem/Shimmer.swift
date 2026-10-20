import SwiftUI

struct Shimmer: ViewModifier {
    var period: Double = 1.4

    func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation) { context in
                    let progress = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.4)
                            .offset(x: -proxy.size.width * 0.4 + progress * proxy.size.width * 1.4)
                    }
                }
                .mask(content)
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }
}
