import SwiftUI

/// A round GitHub avatar, or the account's initial on a color of its own while there's no picture.
struct Avatar: View {
    let url: URL?
    let login: String
    var size: CGFloat = 16

    var body: some View {
        AsyncImage(url: url.map(sized)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            initial
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initial: some View {
        // Same login, same color, so an account is recognizable at a glance.
        let hue = Double(login.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
        return ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(hue: hue, saturation: 0.55, brightness: 0.85), Color(hue: hue, saturation: 0.7, brightness: 0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            Text(login.prefix(1).uppercased())
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func sized(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "s", value: "\(Int(size * 3))")]
        return components.url ?? url
    }
}
