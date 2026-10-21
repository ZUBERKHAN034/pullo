import Foundation

extension SavedFilter {
    static var examples: [SavedFilter] {
        [
            SavedFilter(name: String(localized: "Ready to merge"), query: "author:@me review:approved status:success"),
            SavedFilter(name: String(localized: "Changes requested"), query: "author:@me review:changes_requested"),
            SavedFilter(name: String(localized: "Waiting for review"), query: "author:@me review:required"),
            SavedFilter(name: String(localized: "Failing checks"), query: "author:@me status:failure"),
            SavedFilter(name: String(localized: "My drafts"), query: "author:@me draft:true"),
            SavedFilter(name: String(localized: "Mentions me"), query: "mentions:@me"),
            SavedFilter(name: String(localized: "Reviewed by me"), query: "reviewed-by:@me -author:@me"),
            SavedFilter(name: String(localized: "Involves me"), query: "involves:@me"),
            SavedFilter(name: String(localized: "Recently merged"), query: "author:@me is:merged"),
            SavedFilter(name: String(localized: "A label in a repo"), query: "repo:owner/name label:bug"),
        ]
    }
}
