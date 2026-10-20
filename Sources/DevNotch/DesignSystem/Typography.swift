import SwiftUI

enum TextSize: CGFloat {
    case keycap = 9.5
    case micro = 10
    case caption = 10.5
    case small = 11
    case body = 11.5
    case label = 12
    case title = 12.5
    case headline = 13
    case display = 15
}

extension Font {
    static func panel(_ size: TextSize, _ weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size.rawValue, weight: weight, design: design)
    }

    static let keycap = Font.panel(.keycap, .bold, design: .rounded)
}
