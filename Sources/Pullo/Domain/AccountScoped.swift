import Foundation

protocol AccountScoped: Identifiable, Equatable where ID == UUID {
    var id: UUID { get set }
    var account: String? { get set }
}

extension AccountScoped {
    func applies(to login: String) -> Bool {
        account.map { $0.caseInsensitiveCompare(login) == .orderedSame } ?? true
    }

    func isSameTab(as other: Self) -> Bool {
        var copy = self
        copy.id = other.id
        copy.account = other.account
        return copy == other
    }

    static func merging(_ lists: [(login: String, tabs: [Self])]) -> [Self] {
        var merged: [Self] = []
        for (login, tabs) in lists {
            for tab in tabs {
                var copy = tab
                if lists.allSatisfy({ list in list.tabs.contains { $0.isSameTab(as: tab) } }) {
                    guard !merged.contains(where: { $0.account == nil && $0.isSameTab(as: tab) }) else { continue }
                    copy.account = nil
                } else {
                    copy.account = login
                }
                if merged.contains(where: { $0.id == copy.id }) { copy.id = UUID() }
                merged.append(copy)
            }
        }
        return merged
    }
}
