import Foundation
@testable import Pullo
import Testing

struct AccessibilityTests {
    private func contrastOnBlack(_ opacity: Double) -> Double {
        let linear = opacity <= 0.04045 ? opacity / 12.92 : pow((opacity + 0.055) / 1.055, 2.4)
        return (linear + 0.05) / 0.05
    }

    @Test func increasedContrastMakesEveryTextToneReadable() {
        for tone in TextTone.allCases {
            #expect(contrastOnBlack(tone.opacity(increasedContrast: true)) >= 7)
            #expect(tone.opacity(increasedContrast: true) > tone.opacity(increasedContrast: false))
        }
    }

    @Test func defaultTextTonesStayTheSame() {
        #expect(TextTone.allCases.map { $0.opacity(increasedContrast: false) } == [0.85, 0.6, 0.48, 0.35])
    }

    @Test func shortAgeUsesCompactUnits() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(now.addingTimeInterval(-30).shortAge(at: now) == "now")
        #expect(now.addingTimeInterval(-5 * 60).shortAge(at: now) == "5m")
        #expect(now.addingTimeInterval(-3 * 3600).shortAge(at: now) == "3h")
        #expect(now.addingTimeInterval(-2 * 86400).shortAge(at: now) == "2d")
        #expect(now.addingTimeInterval(60).shortAge(at: now) == "now")
    }

    @Test func runDurationsUseCompactUnits() {
        #expect(RunRow.duration(42) == "42s")
        #expect(RunRow.duration(125) == "2m 5s")
        #expect(RunRow.duration(3720) == "1h 2m")
    }

    @Test(arguments: ["%lldm", "%lldh", "%lldd", "%llds", "%lldm %llds", "%lldh %lldm"])
    func timeUnitsAreTranslated(_ key: String) throws {
        let catalog = try Catalog.load()
        for language in ["pt-BR", "es"] {
            let value = try #require(catalog.translation(of: key, in: language))
            #expect(Catalog.placeholders(in: value) == Catalog.placeholders(in: key))
        }
    }

    @Test func everyStringIsTranslatedWithTheSamePlaceholders() throws {
        let catalog = try Catalog.load()
        for key in catalog.keys {
            for language in ["pt-BR", "es"] {
                let value = catalog.translation(of: key, in: language)
                #expect(value != nil, "\(key) has no \(language) translation")
                if let value { #expect(Catalog.placeholders(in: value) == Catalog.placeholders(in: key), "\(key) in \(language)") }
            }
        }
    }
}

private struct Catalog {
    let strings: [String: Any]

    var keys: [String] {
        strings.filter { ($0.value as? [String: Any])?["shouldTranslate"] as? Bool != false }.keys.sorted()
    }

    static func load() throws -> Catalog {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Pullo/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return Catalog(strings: json?["strings"] as? [String: Any] ?? [:])
    }

    func translation(of key: String, in language: String) -> String? {
        let entry = strings[key] as? [String: Any]
        let localization = (entry?["localizations"] as? [String: Any])?[language] as? [String: Any]
        return (localization?["stringUnit"] as? [String: Any])?["value"] as? String
    }

    static func placeholders(in text: String) -> [String] {
        let pattern = /%(?:\d+\$)?(lld|@|d|ld|f)/
        return text.matches(of: pattern).map { String($0.output.1) }.sorted()
    }
}
