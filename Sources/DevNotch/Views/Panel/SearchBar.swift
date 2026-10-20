import AppKit
import SwiftUI

struct SearchBar: View {
    @ObservedObject var model: NotchViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            SearchField(text: Binding(get: { model.searchQuery }, set: { model.searchQuery = $0 }))
                .frame(height: 18)
            Button {
                model.stopSearch()
            } label: {
                Text("esc")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .hint("Close search", edge: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

struct SearchField: NSViewRepresentable {
    let text: Binding<String>

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 12.5, weight: .medium)
        field.textColor = .white
        field.placeholderAttributedString = NSAttributedString(
            string: "Title, repo, #number, branch or author",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.45),
                .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            ]
        )
        field.delegate = context.coordinator
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
            (field.currentEditor() as? NSTextView)?.insertionPointColor = .white
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        guard field.stringValue != text.wrappedValue else { return }
        field.stringValue = text.wrappedValue
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: text) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
