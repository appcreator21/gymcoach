import AppIntents
import Foundation

/// Where the Live Activity's pause button lands. The widget extension only
/// declares the intent; the app installs the handler when it launches, and the
/// system runs the intent inside the app process.
enum LiveActivityBridge {
    static var handler: (@Sendable (String, Bool) async -> Void)?

    static func handle(sessionId: String, pause: Bool) async {
        await handler?(sessionId, pause)
    }
}

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume workout"
    static let isDiscoverable = false

    @Parameter(title: "Session") var sessionId: String
    @Parameter(title: "Pause") var pause: Bool

    init() {}

    init(sessionId: String, pause: Bool) {
        self.sessionId = sessionId
        self.pause = pause
    }

    func perform() async throws -> some IntentResult {
        await LiveActivityBridge.handle(sessionId: sessionId, pause: pause)
        return .result()
    }
}
