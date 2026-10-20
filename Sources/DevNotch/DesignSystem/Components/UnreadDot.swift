import SwiftUI

struct UnreadDot: View {
    var size: CGFloat = 6

    var body: some View {
        Circle().fill(.unread).frame(width: size, height: size)
    }
}
