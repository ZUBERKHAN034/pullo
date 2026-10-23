import Foundation
import OSLog

struct GHLocation: Equatable {
    let executable: String?
    let configDirectory: String

    static let fallbackDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/opt/local/bin",
        "~/.local/bin",
        "~/.nix-profile/bin",
        "~/.local/share/mise/shims",
        "/run/current-system/sw/bin",
        "/nix/var/nix/profiles/default/bin",
    ].map { NSString(string: $0).expandingTildeInPath }

    static let marker = "__PULLO_GH__"

    var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["GH_CONFIG_DIR"] = configDirectory
        let directories = (executable.map { [URL(fileURLWithPath: $0).deletingLastPathComponent().path] } ?? [])
            + Self.fallbackDirectories + [environment["PATH"] ?? "/usr/bin:/bin"]
        environment["PATH"] = directories.joined(separator: ":")
        return environment
    }

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        shellOutput: String?,
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> GHLocation {
        var fromShell: [String] = []
        if let shellOutput, let range = shellOutput.range(of: marker + "\n", options: .backwards) {
            fromShell = shellOutput[range.upperBound...].components(separatedBy: "\n")
        }
        func shell(_ index: Int) -> String? {
            fromShell.indices.contains(index) ? fromShell[index].trimmed.nilIfEmpty : nil
        }
        let found = shell(0).flatMap { $0.hasPrefix("/") && isExecutable($0) ? $0 : nil }
        let executable = found ?? fallbackDirectories.map { $0 + "/gh" }.first(where: isExecutable)
        let configDirectory = environment["GH_CONFIG_DIR"]?.nilIfEmpty
            ?? shell(1)
            ?? (environment["XDG_CONFIG_HOME"]?.nilIfEmpty ?? shell(2)).map { $0 + "/gh" }
            ?? home + "/.config/gh"
        return GHLocation(executable: executable, configDirectory: configDirectory)
    }

    static func loginShell() -> String {
        let shell = getpwuid(getuid()).flatMap { $0.pointee.pw_shell }.map { String(cString: $0) }
            ?? ProcessInfo.processInfo.environment["SHELL"]
        guard let shell, ["zsh", "bash", "sh", "ksh"].contains(URL(fileURLWithPath: shell).lastPathComponent) else { return "/bin/zsh" }
        return shell
    }

    static func lookUp(timeout: Duration = .seconds(5)) async -> GHLocation {
        let script = #"printf '\n%s\n%s\n%s\n%s\n' "\#(marker)" "$(command -v gh)" "$GH_CONFIG_DIR" "$XDG_CONFIG_HOME""#
        var output: String?
        do {
            let result = try await ProcessRunner.run(loginShell(), ["-ilc", script], timeout: timeout)
            output = String(decoding: result.stdout, as: UTF8.self)
        } catch {
            Logger.github.notice("Asking the login shell for gh failed: \(String(describing: error), privacy: .public)")
        }
        let location = resolve(shellOutput: output)
        Logger.github.info("gh is at \(location.executable ?? "nowhere", privacy: .private(mask: .hash))")
        return location
    }
}

actor GHLocator {
    static let shared = GHLocator()

    private var lookup: Task<GHLocation, Never>?

    func location() async -> GHLocation {
        if let lookup { return await lookup.value }
        let task = Task { await GHLocation.lookUp() }
        lookup = task
        return await task.value
    }

    func reset() {
        lookup = nil
    }
}
