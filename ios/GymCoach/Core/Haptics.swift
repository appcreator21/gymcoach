import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    /// The detent click used for choices, pickers and tab changes.
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

    /// A rising run of taps that ends in a success buzz. Used for big moments.
    static func crescendo(steps: Int = 6) async {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        for step in 0..<steps {
            generator.impactOccurred(intensity: 0.25 + 0.75 * CGFloat(step) / CGFloat(max(steps - 1, 1)))
            try? await Task.sleep(for: .milliseconds(max(45, 130 - step * 18)))
        }
        success()
    }
}
