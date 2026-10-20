import AppKit
import SwiftUI

struct DemoCaption: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

@MainActor
final class DemoStageModel: ObservableObject {
    @Published var caption: DemoCaption?
    @Published var titleCard: DemoCaption?
    @Published var cursor: CGPoint
    @Published var cursorVisible = false

    init(cursor: CGPoint) {
        self.cursor = cursor
    }
}

@MainActor
final class DemoStage {
    let model: DemoStageModel
    /// The recorded region, in display points with a top-left origin (what ScreenCaptureKit expects).
    let captureRect: CGRect

    private let backdrop: NSWindow
    private let pointer: NSWindow

    init(screen: NSScreen, menuBarHeight: CGFloat) {
        let width = min(1280, screen.frame.width)
        let size = CGSize(width: width, height: (width * 9 / 16).rounded())
        captureRect = CGRect(x: ((screen.frame.width - size.width) / 2).rounded(), y: 0, width: size.width, height: size.height)
        model = DemoStageModel(cursor: CGPoint(x: size.width / 2, y: size.height * 0.8))

        let frame = NSRect(
            x: screen.frame.minX + captureRect.minX,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        backdrop = Self.window(frame: frame, level: NSWindow.Level.mainMenu.rawValue + 2,
                               content: StageView(model: model, menuBarHeight: menuBarHeight))
        pointer = Self.window(frame: frame, level: NSWindow.Level.mainMenu.rawValue + 4,
                              content: PointerView(model: model))
    }

    func show() {
        backdrop.orderFrontRegardless()
        pointer.orderFrontRegardless()
    }

    private static func window(frame: NSRect, level: Int, content: some View) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: level)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: content)
        return window
    }
}

private struct StageView: View {
    @ObservedObject var model: DemoStageModel
    let menuBarHeight: CGFloat

    var body: some View {
        ZStack {
            Wallpaper()
            VStack(spacing: 0) {
                FakeMenuBar(height: menuBarHeight)
                Spacer()
            }
            if let card = model.titleCard {
                TitleCard(caption: card)
                    .id(card.id)
                    .transition(.reveal(delay: 0.1))
            }
            if let caption = model.caption {
                CaptionView(caption: caption)
                    .id(caption.id)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 64)
                    .transition(.reveal(delay: 0.05))
            }
        }
        .animation(Motion.reveal, value: model.caption)
        .animation(Motion.reveal, value: model.titleCard)
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.16), Color(red: 0.11, green: 0.07, blue: 0.24)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.45, green: 0.25, blue: 0.95).opacity(0.75), .clear],
                           center: UnitPoint(x: 0.18, y: 0.3), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(red: 1, green: 0.45, blue: 0.3).opacity(0.55), .clear],
                           center: UnitPoint(x: 0.85, y: 0.85), startRadius: 10, endRadius: 480)
            RadialGradient(colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.45), .clear],
                           center: UnitPoint(x: 0.65, y: 0.15), startRadius: 10, endRadius: 380)
        }
    }
}

private struct FakeMenuBar: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: 18) {
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window"], id: \.self) { Text($0) }
            Spacer()
            ForEach(["magnifyingglass", "wifi", "battery.75percent", "switch.2"], id: \.self) { Image(systemName: $0) }
            Text("Fri Oct 3  10:42 AM")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 22)
        .frame(height: height)
        .background(Color.black.opacity(0.22))
    }
}

private struct CaptionView: View {
    let caption: DemoCaption

    var body: some View {
        VStack(spacing: 8) {
            Text(caption.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(caption.subtitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }
}

private struct TitleCard: View {
    let caption: DemoCaption

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 88, height: 88)
            .shadow(color: .purple.opacity(0.6), radius: 30)
            Text(caption.title)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(caption.subtitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 60)
    }
}

/// A drawn arrow standing in for the real pointer, which ScreenCaptureKit leaves out.
private struct PointerView: View {
    @ObservedObject var model: DemoStageModel

    var body: some View {
        ArrowShape()
            .fill(.black)
            .overlay(ArrowShape().stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)))
            .frame(width: 17, height: 25)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            .position(x: model.cursor.x + 6, y: model.cursor.y + 11)
            .opacity(model.cursorVisible ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.47, y: h))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.93))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.55))
        path.addLine(to: CGPoint(x: w, y: h * 0.55))
        path.closeSubpath()
        return path
    }
}
