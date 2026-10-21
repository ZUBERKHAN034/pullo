import Foundation

struct Account: Identifiable, Codable, Equatable {
    let login: String
    let avatarURL: URL?
    var filters: [SavedFilter] = SavedFilter.defaults
    var runTabs: [RunTab] = RunTab.defaults

    var id: String { login }
}

extension Account {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        login = try container.decode(String.self, forKey: .login)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        filters = try container.decodeIfPresent([SavedFilter].self, forKey: .filters) ?? SavedFilter.defaults
        runTabs = (try? container.decodeIfPresent([RunTab].self, forKey: .runTabs)) ?? RunTab.defaults
    }
}
