import SwiftUI

/// Every animation in the app, so the notch moves with one consistent feel.
enum Motion {
    /// The notch growing into the panel.
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.78)
    /// The notch shrinking back; firmer, so it settles without a wobble.
    static let close = Animation.spring(response: 0.36, dampingFraction: 0.92)
    /// An alert dropping out of the notch; a little bouncy so it catches the eye.
    static let peek = Animation.spring(response: 0.5, dampingFraction: 0.7)
    /// Moving around inside the panel: tabs, accounts, screens, search, selection.
    static let navigate = Animation.spring(response: 0.33, dampingFraction: 0.84)
    /// Content fading and sliding in after the shape has started to grow.
    static let reveal = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Small elements popping in, like stacked alert icons or a hovered button.
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Highlights following the pointer.
    static let hover = Animation.easeOut(duration: 0.14)
    /// Things quietly going away.
    static let fade = Animation.easeOut(duration: 0.2)
}
