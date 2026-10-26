import Foundation

/// UserDefaults keys for the on-device preferences. Views bind to these with
/// @AppStorage; non-view code reads them through `Prefs.bool`.
enum Prefs {
    static let keepAwake = "pref.keepAwake"
    static let autoRest = "pref.autoRest"
    static let healthSync = "pref.healthSync"
    static let haptics = "pref.haptics"
    static let voiceCues = "pref.voiceCues"

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
}
