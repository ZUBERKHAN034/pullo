import Foundation
import os

final class QuerySizes: Sendable {
    static let downgradeTime: TimeInterval = 30 * 60

    private let lightUntil = OSAllocatedUnfairLock(initialState: [String: Date]())
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
    }

    func usesLight(_ account: String) -> Bool {
        let now = now()
        return lightUntil.withLock { until in
            guard let end = until[account] else { return false }
            if now < end { return true }
            until[account] = nil
            return false
        }
    }

    func downgrade(_ account: String) {
        let end = now().addingTimeInterval(Self.downgradeTime)
        lightUntil.withLock { $0[account] = end }
    }
}

extension URLSession {
    static let github: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
}
