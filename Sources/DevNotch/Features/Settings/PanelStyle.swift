import Foundation

enum PanelStyle: String, CaseIterable {
    case solid, glass, glassDarkTop

    static var glassIsAvailable: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    var isGlass: Bool { self != .solid }

    func usesGlass(reduceTransparency: Bool) -> Bool {
        isGlass && Self.glassIsAvailable && !reduceTransparency
    }

    var title: String {
        switch self {
        case .solid: String(localized: "Solid")
        case .glass: String(localized: "Glass")
        case .glassDarkTop: String(localized: "Glass with a dark top")
        }
    }
}
