import OSLog

extension Logger {
    private static let subsystem = "dev.jrdan.devnotch"

    static let github = Logger(subsystem: subsystem, category: "github")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
