import SwiftUI

extension View {
    func hint(_ text: String, edge: HorizontalEdge = .trailing) -> some View {
        modifier(HoverHint(text: text, edge: edge))
    }
}

private struct HoverHint: ViewModifier {
    let text: String
    let edge: HorizontalEdge
    @State private var shown = false
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                pending?.cancel()
                guard inside, !text.isEmpty else {
                    withAnimation(Motion.fade) { shown = false }
                    return
                }
                pending = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    withAnimation(Motion.fade) { shown = true }
                }
            }
            .overlay(alignment: edge == .trailing ? .trailing : .leading) {
                label
                    .fixedSize()
                    .alignmentGuide(edge == .trailing ? .trailing : .leading) { size in
                        edge == .trailing ? size[.leading] - 8 : size[.trailing] + 8
                    }
                    .opacity(shown ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .zIndex(shown ? 1 : 0)
    }

    private var label: some View {
        Text(text)
            .font(.panel(.small, .medium))
            .foregroundStyle(.textStrong)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
    }
}
