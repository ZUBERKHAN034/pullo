import SwiftUI

extension View {
    /// Explains a control on hover. Stands in for `.help`: the panel never activates the app, and macOS only
    /// shows system tooltips for the active one, so they never appeared.
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
            // Always laid out and faded in: inside an `if`, SwiftUI drops the alignment guide and the hint lands on
            // top of the view instead of beside it.
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
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
    }
}
