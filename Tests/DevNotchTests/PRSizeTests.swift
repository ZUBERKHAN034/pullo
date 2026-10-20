@testable import DevNotch
import Foundation
import Testing

struct PRSizeTests {
    private let english = Locale(identifier: "en_US")

    @Test func smallCountsStayExact() {
        #expect(PRSizeLabel.compact(0) == "0")
        #expect(PRSizeLabel.compact(999) == "999")
    }

    @Test func shortenedThousandsUseTheLocaleSeparator() {
        #expect(PRSizeLabel.compact(1234, locale: Locale(identifier: "pt_BR")) == "1,2k")
    }

    @Test func thousandsAreShortened() {
        #expect(PRSizeLabel.compact(1000, locale: english) == "1k")
        #expect(PRSizeLabel.compact(1234, locale: english) == "1.2k")
        #expect(PRSizeLabel.compact(15800, locale: english) == "15.8k")
    }
}
