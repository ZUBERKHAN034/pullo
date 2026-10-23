import Foundation

struct PollGate {
    enum Hold: Equatable {
        case backoff(until: Date)
        case rateLimited(until: Date)
        case signIn
    }

    static let firstBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 300
    static let unknownRateLimitWait: TimeInterval = 300

    private(set) var holds: [String: Hold] = [:]
    private var failures: [String: Int] = [:]
    private let jitter: () -> Double

    init(jitter: @escaping () -> Double = { Double.random(in: 0.75...1) }) {
        self.jitter = jitter
    }

    func allows(_ login: String, at now: Date) -> Bool {
        switch holds[login] {
        case nil: true
        case .backoff(let until), .rateLimited(let until): now >= until
        case .signIn: false
        }
    }

    func next(_ login: String) -> Date? {
        switch holds[login] {
        case .backoff(let until), .rateLimited(let until): until
        default: nil
        }
    }

    mutating func succeeded(_ login: String) {
        holds[login] = nil
        failures[login] = nil
    }

    mutating func failed(_ login: String, with error: Error, at now: Date) {
        switch error as? GitHubError {
        case .rateLimited(let until)?:
            holds[login] = .rateLimited(until: max(until ?? now.addingTimeInterval(Self.unknownRateLimitWait), now))
        case .unauthorized?, .noToken?:
            holds[login] = .signIn
        default:
            let count = (failures[login] ?? 0) + 1
            failures[login] = count
            holds[login] = .backoff(until: now.addingTimeInterval(backoff(after: count)))
        }
    }

    func backoff(after failures: Int) -> TimeInterval {
        let exponent = Double(max(0, min(failures - 1, 10)))
        return min(Self.maxBackoff, Self.firstBackoff * pow(2, exponent)) * jitter()
    }

    mutating func clearForManualRefresh() {
        holds = holds.filter { if case .rateLimited = $0.value { true } else { false } }
        failures = [:]
    }

    mutating func clearBackoff() {
        holds = holds.filter { if case .backoff = $0.value { false } else { true } }
        failures = [:]
    }

    mutating func prune(to logins: Set<String>) {
        holds = holds.filter { logins.contains($0.key) }
        failures = failures.filter { logins.contains($0.key) }
    }
}
