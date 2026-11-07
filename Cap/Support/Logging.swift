import OSLog

enum Log {
    private static let subsystem = "dev.bruce.cap"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let selection = Logger(subsystem: subsystem, category: "selection")
    static let editor = Logger(subsystem: subsystem, category: "editor")
    static let history = Logger(subsystem: subsystem, category: "history")
}
