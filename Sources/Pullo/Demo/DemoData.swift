import Foundation

#if DEBUG
    enum DemoData {
        static let work = Account(login: "ana-acme", avatarURL: nil)
        static let personal = Account(login: "dev-ana", avatarURL: nil)

        static func freshDefaults() -> UserDefaults {
            let suite = "dev.jrdan.devnotch.demo"
            UserDefaults().removePersistentDomain(forName: suite)
            guard let defaults = UserDefaults(suiteName: suite) else { preconditionFailure("No defaults suite \(suite)") }
            defaults.set(try? JSONEncoder().encode([work, personal]), for: .accounts)
            defaults.set(false, for: .haptics)
            defaults.set("", for: .sound)
            return defaults
        }

        enum Moment {
            case calm, news, ciFixed
        }

        static func snapshots(at moment: Moment) -> [String: Snapshot] {
            [work.login: workSnapshot(at: moment), personal.login: personalSnapshot]
        }

        private static func workSnapshot(at moment: Moment) -> Snapshot {
            let news = moment != .calm
            let checkout = pr(
                "PR_482", work, 482, "feat: Apple Pay checkout", "acme/checkout", "feat/apple-pay", work.login, hoursAgo: 20,
                ci: moment == .calm ? .pending : (moment == .news ? .failure : .success),
                comments: news ? ["c1", "c2"] : [],
                reviews: news ? [Activity(id: "r1", author: "rafa-lima")] : [],
                failedChecks: moment == .news ? [FailedCheck(name: "Typecheck", url: nil)] : []
            )
            let webhook = pr(
                "PR_1291", work, 1291, "fix: retry payment webhook", "acme/api", "fix/webhook-retry", work.login, hoursAgo: 26,
                review: news ? .approved : nil, approvers: news ? ["rafa-lima"] : [],
                reviews: news ? [Activity(id: "r2", author: "rafa-lima")] : []
            )
            let mine = [
                checkout,
                webhook,
                pr("PR_1287", work, 1287, "refactor: extract HTTP client", "acme/api", "refactor/http-client", work.login, hoursAgo: 50,
                   review: .approved, approvers: ["teo"]),
                pr("PR_310", work, 310, "feat: new app onboarding", "acme/mobile", "feat/onboarding-v2", work.login, hoursAgo: 72,
                   review: .changesRequested, conflict: true),
                pr("PR_733", work, 733, "chore: update dependencies", "acme/web", "chore/deps-october", work.login, hoursAgo: 4,
                   ci: nil, draft: true),
            ]
            var review = [
                pr("PR_741", work, 741, "feat: discount codes in cart", "acme/web", "feat/coupons", "bruno-s", hoursAgo: 30),
                pr("PR_1295", work, 1295, "fix: time zones in reports", "acme/api", "fix/report-timezone", "teo", hoursAgo: 3),
                pr("PR_1280", work, 1280, "perf: cache the catalog", "acme/api", "perf/catalog-cache", "marina-dev", hoursAgo: 52),
                pr("PR_88", work, 88, "docs: deploy guide", "acme/infra", "docs/deploy-guide", "rafa-lima", hoursAgo: 8,
                   request: .team(["platform"])),
                pr("PR_1299", work, 1299, "feat: per-tenant flags", "acme/api", "feat/tenant-flags", "bruno-s", hoursAgo: 6,
                   request: .team(["backend"])),
                pr("PR_479", work, 479, "test: checkout e2e", "acme/checkout", "test/checkout-e2e", "teo", hoursAgo: 28,
                   request: .team(["qa"])),
            ]
            if news {
                review.insert(pr("PR_1302", work, 1302, "fix: shipping rounding", "acme/api", "fix/shipping-rounding",
                                 "marina-dev", hoursAgo: 0.1), at: 0)
            }
            return Snapshot(mine: mine, reviewRequests: review)
        }

        private static var personalSnapshot: Snapshot {
            Snapshot(
                mine: [
                    pr("PR_12", personal, 12, "feat: dark mode", "dev-ana/blog", "feat/dark-mode", personal.login, hoursAgo: 40),
                    pr("PR_7", personal, 7, "fix: broken RSS links", "dev-ana/blog", "fix/rss-links", personal.login, hoursAgo: 90,
                       review: .approved, approvers: ["lucasm"]),
                ],
                reviewRequests: [
                    pr("PR_21", personal, 21, "zsh: faster git plugin", "lucasm/dotfiles", "zsh/fast-git", "lucasm", hoursAgo: 14),
                ]
            )
        }

        private static func pr(
            _ id: String, _ account: Account, _ number: Int, _ title: String, _ repo: String, _ branch: String, _ author: String,
            hoursAgo: Double,
            ci: CIState? = .success,
            review: ReviewDecision? = nil,
            approvers: [String] = [],
            comments: [String] = [],
            reviews: [Activity] = [],
            failedChecks: [FailedCheck] = [],
            conflict: Bool = false,
            draft: Bool = false,
            request: ReviewRequest = .direct
        ) -> PullRequest {
            let created = Date().addingTimeInterval(-hoursAgo * 3600)
            return PullRequest(
                id: id, account: account.login, number: number, title: title,
                url: .pullRequest(repo: repo, number: number),
                repo: repo, branch: branch, author: author, isDraft: draft,
                createdAt: created, updatedAt: created,
                ci: ci, review: review, hasConflict: conflict,
                othersComments: comments.map { Activity(id: $0, author: "marina-dev") }, othersReviews: reviews,
                headOID: "head-\(id)", commitCount: 3,
                approvers: approvers, changeRequesters: review == .changesRequested ? ["marina-dev"] : [],
                reviewRequest: request, failedChecks: failedChecks,
                size: PRSize(additions: number * 37 % 640 + 4, deletions: number * 13 % 180, changedFiles: number % 14 + 1)
            )
        }
    }

    actor DemoSource: PRSource {
        private var snapshots = DemoData.snapshots(at: .calm)
        private var firstFetchDelay: Duration? = .seconds(8.5)

        func show(_ moment: DemoData.Moment) {
            snapshots = DemoData.snapshots(at: moment)
        }

        func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
            if let delay = firstFetchDelay {
                try await Task.sleep(for: delay)
                firstFetchDelay = nil
            }
            guard let snapshot = snapshots[account.login] else { throw GitHubError.noToken }
            return snapshot
        }
    }
#endif
