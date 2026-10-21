import Foundation
import OSLog

struct GHCLI: GitHubCLI {
    var host = "github.com"
    var timeout: Duration = .seconds(10)

    var isInstalled: Bool { Self.executable != nil }

    private static var executable: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
    }

    func users() -> [String] {
        let configDir = ProcessInfo.processInfo.environment["GH_CONFIG_DIR"] ?? NSHomeDirectory() + "/.config/gh"
        guard isInstalled else { return [] }
        let hosts: String
        do {
            hosts = try String(contentsOfFile: configDir + "/hosts.yml", encoding: .utf8)
        } catch {
            Logger.github.notice("Reading gh's hosts.yml failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
        return Self.users(inHostsFile: hosts, host: host)
    }

    static func users(inHostsFile text: String, host: String) -> [String] {
        var users: [String] = []
        var inHost = false
        var usersIndent: Int?
        var childIndent: Int?
        for line in text.split(separator: "\n") {
            let indent = line.prefix(while: { $0 == " " }).count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indent == 0 {
                inHost = trimmed == "\(host):"
                usersIndent = nil
                continue
            }
            guard inHost else { continue }
            if let parent = usersIndent {
                if indent > parent {
                    if childIndent == nil { childIndent = indent }
                    if indent == childIndent, trimmed.hasSuffix(":") { users.append(String(trimmed.dropLast())) }
                    continue
                }
                usersIndent = nil
            }
            if trimmed == "users:" {
                usersIndent = indent
                childIndent = nil
            }
        }
        return users
    }

    func token(for user: String) throws -> String {
        guard let executable = Self.executable else { throw GitHubError.noToken }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["auth", "token", "--hostname", host, "--user", user]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()
        if exited.wait(timeout: .now() + .milliseconds(Int(timeout / .milliseconds(1)))) == .timedOut {
            process.terminate()
            throw GitHubError.ghTimedOut
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()

        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !token.isEmpty else { throw GitHubError.noToken }
        return token
    }
}
