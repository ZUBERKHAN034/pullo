import SwiftUI

extension View {
    func hint(_ text: String) -> some View {
        modifier(HoverHint(text: text))
    }

    func hintLayer(within area: CGSize) -> some View {
        overlayPreferenceValue(HintKey.self) { hints in
            GeometryReader { proxy in
                if let hint = hints.last {
                    let frame = CGRect(x: (proxy.size.width - area.width) / 2, y: 0, width: area.width, height: area.height)
                    HintPlacement(target: proxy[hint.anchor], pointerX: hint.pointerX, area: frame) {
                        HintBubble(text: hint.text)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

#if DEBUG
    extension EnvironmentValues {
        @Entry var forcedHint: String?
    }
#endif

private struct HintRequest {
    let text: String
    let anchor: Anchor<CGRect>
    let pointerX: CGFloat?
}

private struct HintKey: PreferenceKey {
    static let defaultValue: [HintRequest] = []

    static func reduce(value: inout [HintRequest], nextValue: () -> [HintRequest]) {
        value += nextValue()
    }
}

private struct HoverHint: ViewModifier {
    let text: String
    @State private var shown = false
    @State private var pointerX: CGFloat?
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if !shown { pointerX = location.x }
                    guard pending == nil, !shown, !text.isEmpty else { return }
                    pending = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled else { return }
                        pending = nil
                        withAnimation(Motion.fade) { shown = true }
                    }
                case .ended:
                    hide()
                }
            }
            .simultaneousGesture(TapGesture().onEnded { hide() })
            .onDisappear { hide() }
            .anchorPreference(key: HintKey.self, value: .bounds) { anchor in
                isShown ? [HintRequest(text: text, anchor: anchor, pointerX: pointerX)] : []
            }
    }

    #if DEBUG
        @Environment(\.forcedHint) private var forcedHint

        private var isShown: Bool { shown || forcedHint == text }
    #else
        private var isShown: Bool { shown }
    #endif

    private func hide() {
        pending?.cancel()
        pending = nil
        guard shown else { return }
        withAnimation(Motion.fade) { shown = false }
    }
}

private struct HintPlacement: Layout {
    static let gap: CGFloat = 6
    static let margin: CGFloat = 8
    static let maxWidth: CGFloat = 300

    let target: CGRect
    let pointerX: CGFloat?
    let area: CGRect

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let bubble = subviews.first else { return }
        let room = area.insetBy(dx: Self.margin, dy: Self.margin)
        let ideal = bubble.sizeThatFits(.unspecified)
        let size = ideal.width <= min(Self.maxWidth, room.width) ? ideal
            : bubble.sizeThatFits(ProposedViewSize(width: min(Self.maxWidth, room.width), height: nil))
        let centerX = pointerX.map { target.minX + min(max($0, 0), target.width) } ?? target.midX
        let x = min(max(centerX - size.width / 2, room.minX), room.maxX - size.width)
        let below = target.maxY + Self.gap
        let y = below + size.height <= room.maxY ? below : max(target.minY - Self.gap - size.height, room.minY)
        bubble.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
    }
}

private struct HintBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.panel(.small, .medium))
            .foregroundStyle(.textStrong)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
    }
}
