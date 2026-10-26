import UIKit

/// Haptic feedback. The generators are kept alive and re-armed after every
/// use: a generator created and dropped on the spot can fail to fire on a
/// real device. Everything respects the in-app Haptics switch.
enum Haptics {
    private static var enabled: Bool { Prefs.bool(Prefs.haptics, default: true) }

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let softer = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidity = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    private static func fire(_ work: @escaping () -> Void) {
        guard enabled else { return }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    static func tap() { fire { light.impactOccurred(); light.prepare() } }
    static func soft() { fire { softer.impactOccurred(); softer.prepare() } }
    static func rigid() { fire { rigidity.impactOccurred(); rigidity.prepare() } }
    static func thud() { fire { heavy.impactOccurred(); heavy.prepare() } }
    /// The detent click used for choices, pickers and tab changes.
    static func select() { fire { selection.selectionChanged(); selection.prepare() } }
    static func success() { fire { notification.notificationOccurred(.success); notification.prepare() } }
    static func warning() { fire { notification.notificationOccurred(.warning); notification.prepare() } }

    /// A rising run of taps that ends in a success buzz. Used for big moments.
    static func crescendo(steps: Int = 6) async {
        for step in 0..<steps {
            let intensity = 0.25 + 0.75 * CGFloat(step) / CGFloat(max(steps - 1, 1))
            fire { rigidity.impactOccurred(intensity: intensity); rigidity.prepare() }
            try? await Task.sleep(for: .milliseconds(max(45, 130 - step * 18)))
        }
        success()
    }
}
