import SwiftUI

extension EnvironmentValues {
    @Entry var panelGlass = false
}

private struct PanelGlass<S: Shape>: ViewModifier {
    @Environment(\.panelGlass) private var glass
    let active: Bool
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) {
            content.glassEffect(active ? (interactive ? .regular.interactive() : .regular) : .identity, in: shape)
        } else {
            content
        }
    }
}

extension View {
    func panelGlass(_ active: Bool = true, in shape: some Shape, interactive: Bool = true) -> some View {
        modifier(PanelGlass(active: active, shape: shape, interactive: interactive))
    }

    @ViewBuilder
    func glassGroup(spacing: CGFloat) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

struct SelectionCapsule: View {
    @Environment(\.panelGlass) private var glass
    var fill: Color = .surface

    var body: some View {
        if !glass {
            Capsule().fill(fill)
        }
    }
}
