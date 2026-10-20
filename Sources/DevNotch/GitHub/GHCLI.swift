import Foundation

enum GHCLI {
    static var isInstalled: Bool { executable != nil }

    // GUI apps don't inherit the shell PATH, so look for gh where installers put it.
    private static var executable: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
    }

    static func users(host: String = "github.com") -> [String] {
        let configDir = ProcessInfo.processInfo.environment["GH_CONFIG_DIR"] ?? NSHomeDirectory() + "/.config/gh"
        guard isInstalled, let hosts = try? String(contentsOfFile: configDir + "/hosts.yml", encoding: .utf8) else {
            return []
        }
        return users(inHostsFile: hosts, host: host)
    }

    /// gh writes hosts.yml in a fixed shape (host → users → one key per account), so a line scan is enough.
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

    /// gh can stall, e.g. waiting on a keychain prompt nobody sees, so it gets a deadline instead of hanging a thread.
    static func token(for user: String, host: String = "github.com", timeout: Duration = .seconds(10)) throws -> String {
        guard let executable else { throw GitHubError.noToken }
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
        // A token is far smaller than the pipe's buffer, so gh can exit before anyone reads it.
        let data = output.fileHandleForReading.readDataToEndOfFile()

        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !token.isEmpty else { throw GitHubError.noToken }
        return token
    }
}
