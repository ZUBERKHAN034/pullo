import Foundation
import OSLog

struct GHCLI: GitHubCLI {
    var host = "github.com"
    var timeout: Duration = .seconds(10)

    var locator = GHLocator.shared

    func isInstalled() async -> Bool {
        await locator.location().executable != nil
    }

    func recheck() async {
        await locator.reset()
    }

    func users() async -> [String] {
        let location = await locator.location()
        guard location.executable != nil else { return [] }
        let hosts: String
        do {
            hosts = try String(contentsOfFile: location.configDirectory + "/hosts.yml", encoding: .utf8)
        } catch {
            Logger.github.notice("Reading gh's hosts.yml failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
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

    func token(for user: String) async throws -> String {
        let location = await locator.location()
        guard let executable = location.executable else { throw GitHubError.noToken }
        let output: ProcessRunner.Output
        do {
            output = try await ProcessRunner.run(
                executable,
                ["auth", "token", "--hostname", host, "--user", user],
                environment: location.environment,
                timeout: timeout
            )
        } catch is ProcessRunner.TimedOut {
            throw GitHubError.ghTimedOut
        } catch {
            Logger.github.error("Running gh failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            throw GitHubError.noToken
        }
        let token = String(decoding: output.stdout, as: UTF8.self).trimmed
        guard output.status == 0, !token.isEmpty else { throw GitHubError.noToken }
        return token
    }
}
