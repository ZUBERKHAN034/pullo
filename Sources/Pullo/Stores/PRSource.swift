import Foundation

protocol PRSource: Sendable {
    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot
    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome]
}

extension PRSource {
    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] { [] }
}
