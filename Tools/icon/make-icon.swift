import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let iconSize: CGFloat = 824

func hex(_ v: UInt32, _ a: Double = 1) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: a)
}

struct Frame<Content: View>: View {
    var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        content
            .frame(width: iconSize, height: iconSize)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
            .frame(width: canvas, height: canvas)
    }
}

struct Rays: View {
    var color: Color
    var count = 72
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let len = CGFloat(40 + (i * 37) % 90)
                Capsule().fill(LinearGradient(colors: [color.opacity(0.55), color.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 5, height: len)
                    .offset(y: -(205 + len / 2))
                    .rotationEffect(.degrees(Double(i) * 360 / Double(count) + Double((i * 13) % 5)))
            }
        }
        .blur(radius: 6)
    }
}

struct Eclipse: View {
    var bg: (UInt32, UInt32)
    var inner: UInt32
    var mid: UInt32
    var outer: UInt32
    var offset: CGFloat = -24

    var body: some View {
        Frame(content: ZStack {
            RadialGradient(colors: [hex(bg.0), hex(bg.1)], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 620)
            Circle().fill(RadialGradient(colors: [hex(outer, 0.35), .clear], center: .center, startRadius: 200, endRadius: 420))
                .frame(width: 840)
            Rays(color: hex(mid))
            Circle().fill(RadialGradient(stops: [
                .init(color: hex(inner), location: 0.0),
                .init(color: hex(inner), location: 0.56),
                .init(color: hex(mid), location: 0.64),
                .init(color: hex(outer, 0.6), location: 0.8),
                .init(color: hex(outer, 0), location: 1.0),
            ], center: .center, startRadius: 0, endRadius: 330)).frame(width: 660)
            Circle().fill(hex(bg.1)).frame(width: 388).offset(y: offset)
            Circle().stroke(LinearGradient(colors: [hex(inner), hex(inner, 0.2)], startPoint: .bottom, endPoint: .top), lineWidth: 5)
                .frame(width: 392).offset(y: offset).blur(radius: 1.5)
        })
    }
}

@MainActor
func render(to path: String) {
    let icon = Eclipse(bg: (0x1C1915, 0x060505), inner: 0xFFF6E0, mid: 0xFFC25A, outer: 0xFF6A2A)
    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("Rendering the icon failed") }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        fatalError("Writing \(path) failed: \(error)")
    }
}

MainActor.assumeIsolated { render(to: CommandLine.arguments[1]) }
