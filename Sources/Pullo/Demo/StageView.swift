import AppKit
import SwiftUI

#if DEBUG
    struct StageView: View {
        let model: DemoStageModel
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
            Color(red: 0.27, green: 0.28, blue: 0.3)
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
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 104, height: 104)
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
#endif
