import AppKit
@testable import DevNotch
import Testing
import UniformTypeIdentifiers

struct PRDragItemTests {
    @Test func offersTheLinkAsURLAndPlainText() {
        let pr = PullRequest.make(id: "PR_1")
        let types = pr.dragItem.registeredTypeIdentifiers
        #expect(types.contains(UTType.url.identifier))
        #expect(types.contains { UTType($0)?.conforms(to: .plainText) == true })
    }
}
