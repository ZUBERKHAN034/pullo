@testable import DevNotch
import Testing

@MainActor
struct UpdateChannelsTests {
    @Test func onlyStableVersionsUntilBetasAreTurnedOn() {
        let scratch = ScratchDefaults()
        #expect(UpdateChannels(defaults: scratch.defaults).allowed.isEmpty)
    }

    @Test func turningBetasOnAddsTheBetaChannelAndIsRemembered() {
        let scratch = ScratchDefaults()
        UpdateChannels(defaults: scratch.defaults).receivesBetas = true
        #expect(UpdateChannels(defaults: scratch.defaults).allowed == ["beta"])
    }
}
